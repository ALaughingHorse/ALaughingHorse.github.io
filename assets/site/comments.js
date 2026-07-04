(async () => {
  const root = document.querySelector("[data-comments-root]");
  const config = window.ALH_COMMENTS_CONFIG;

  if (!root || !config?.enabled) {
    if (root) root.hidden = true;
    return;
  }

  const postId = root.dataset.postId;
  const status = root.querySelector("[data-comments-status]");
  const list = root.querySelector("[data-comments-list]");
  const form = root.querySelector("[data-comments-form]");
  const textarea = root.querySelector("[data-comments-text]");
  const signIn = root.querySelector("[data-comments-sign-in]");
  const signOut = root.querySelector("[data-comments-sign-out]");
  const userLabel = root.querySelector("[data-comments-user]");

  const [
    { initializeApp },
    { getAuth, GoogleAuthProvider, onAuthStateChanged, signInWithPopup, signOut: firebaseSignOut },
    { getFirestore, addDoc, collection, deleteDoc, doc, onSnapshot, orderBy, query, serverTimestamp }
  ] = await Promise.all([
    import("https://www.gstatic.com/firebasejs/10.12.5/firebase-app.js"),
    import("https://www.gstatic.com/firebasejs/10.12.5/firebase-auth.js"),
    import("https://www.gstatic.com/firebasejs/10.12.5/firebase-firestore.js")
  ]);

  const app = initializeApp(config.firebaseConfig);
  const auth = getAuth(app);
  const db = getFirestore(app);
  const provider = new GoogleAuthProvider();
  const commentsRef = collection(db, config.collection || "comments", postId, "items");

  let currentUser = null;
  const admins = new Set(config.adminUids || []);

  signIn.addEventListener("click", () => signInWithPopup(auth, provider));
  signOut.addEventListener("click", () => firebaseSignOut(auth));

  onAuthStateChanged(auth, user => {
    currentUser = user;
    form.hidden = !user;
    signIn.hidden = !!user;
    signOut.hidden = !user;
    userLabel.textContent = user ? `Signed in as ${user.displayName || user.email}` : "Sign in with Google to comment.";
  });

  form.addEventListener("submit", async event => {
    event.preventDefault();
    const text = textarea.value.trim();
    if (!text || !currentUser) return;

    textarea.disabled = true;
    await addDoc(commentsRef, {
      text,
      uid: currentUser.uid,
      authorName: currentUser.displayName || "Anonymous",
      authorPhoto: currentUser.photoURL || "",
      createdAt: serverTimestamp()
    });
    textarea.value = "";
    textarea.disabled = false;
  });

  onSnapshot(query(commentsRef, orderBy("createdAt", "asc")), snapshot => {
    status.textContent = snapshot.empty ? "No comments yet." : "";
    list.innerHTML = "";
    snapshot.forEach(item => {
      const data = item.data();
      const canDelete = currentUser && (currentUser.uid === data.uid || admins.has(currentUser.uid));
      const article = document.createElement("article");
      article.className = "comment";

      const avatar = data.authorPhoto ? `<img src="${escapeHtml(data.authorPhoto)}" alt="">` : "";
      const when = data.createdAt?.toDate ? data.createdAt.toDate().toLocaleDateString() : "";
      article.innerHTML = `
        <div class="comment-author">${avatar}<strong>${escapeHtml(data.authorName || "Anonymous")}</strong><span>${escapeHtml(when)}</span></div>
        <p>${escapeHtml(data.text || "")}</p>
        ${canDelete ? `<button class="comment-delete" type="button">Delete</button>` : ""}
      `;

      const deleteButton = article.querySelector(".comment-delete");
      if (deleteButton) {
        deleteButton.addEventListener("click", () => deleteDoc(doc(commentsRef, item.id)));
      }
      list.append(article);
    });
  }, error => {
    status.textContent = `Comments failed to load: ${error.message}`;
  });

  function escapeHtml(value) {
    return String(value)
      .replaceAll("&", "&amp;")
      .replaceAll("<", "&lt;")
      .replaceAll(">", "&gt;")
      .replaceAll('"', "&quot;")
      .replaceAll("'", "&#39;");
  }
})();
