const {setGlobalOptions} = require("firebase-functions/v2");
const admin = require("firebase-admin");

// Región por defecto de callables/triggers Gen 2.
setGlobalOptions({
  region: "us-central1",
});

if (!admin.apps.length) {
  admin.initializeApp();
}

const db = () => admin.firestore();

module.exports = {admin, db};
