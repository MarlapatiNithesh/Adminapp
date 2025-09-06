// middlewares/authMiddleware.js
const { admin } = require("../config/firebase");

const authMiddleware = async (req, res, next) => {
  try {
    // 1. Check if Authorization header exists
    const authHeader = req.headers.authorization;
    if (!authHeader || !authHeader.startsWith("Bearer ")) {
      return res.status(401).json({ message: "No token provided" });
    }

    // 2. Extract token
    const idToken = authHeader.split(" ")[1];
    if (!idToken) {
      return res.status(401).json({ message: "Invalid token format" });
    }

    console.log("🔑 Received Token:", idToken.substring(0, 20) + "..."); // log first 20 chars only

    // 3. Verify token with Firebase Admin SDK
    const decodedToken = await admin.auth().verifyIdToken(idToken);

    // 4. Attach decoded user info to request
    req.user = decodedToken;
    console.log("✅ Token verified for UID:", decodedToken.uid);

    // 5. Continue to protected route
    next();
  } catch (error) {
    console.error("❌ Token verification error:", error.code || error.message);

    // Handle specific Firebase errors
    if (error.code === "auth/id-token-expired") {
      return res.status(401).json({ message: "Token expired, please re-login" });
    }
    if (error.code === "auth/argument-error") {
      return res.status(401).json({ message: "Invalid token format" });
    }

    return res.status(401).json({ message: "Unauthorized" });
  }
};

module.exports = authMiddleware;

