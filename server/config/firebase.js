// config/firebase.js
const admin = require('firebase-admin');

// ✅ No need to require the JSON directly if GOOGLE_APPLICATION_CREDENTIALS is set
admin.initializeApp({
  credential: admin.credential.applicationDefault(),
});

const db = admin.firestore();

module.exports = { admin, db };
