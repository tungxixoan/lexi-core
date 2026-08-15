// Manual verification script for onCall functions with no frontend yet.
// Usage: node scripts/verify-onCall.mjs <functionName> '<jsonData>'
// Requires: Application Default Credentials set up (gcloud auth application-default login),
// and FIREBASE_WEB_API_KEY set to the Web API key from Firebase Console > Project settings.
import { initializeApp, applicationDefault } from "firebase-admin/app";
import { getAuth } from "firebase-admin/auth";

const [, , functionName, jsonData] = process.argv;
const app = initializeApp({ credential: applicationDefault(), projectId: "lexi-core" });

const customToken = await getAuth(app).createCustomToken("verify-script-uid");

const signInRes = await fetch(
  `https://identitytoolkit.googleapis.com/v1/accounts:signInWithCustomToken?key=${process.env.FIREBASE_WEB_API_KEY}`,
  {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify({ token: customToken, returnSecureToken: true }),
  }
);
const { idToken } = await signInRes.json();

const callableRes = await fetch(
  `https://asia-southeast1-lexi-core.cloudfunctions.net/${functionName}`,
  {
    method: "POST",
    headers: { "Content-Type": "application/json", Authorization: `Bearer ${idToken}` },
    body: JSON.stringify({ data: JSON.parse(jsonData) }),
  }
);
console.log(await callableRes.json());
