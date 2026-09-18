const sdk = require("node-appwrite");

/**
 * Appwrite Cloud Function to reset a user's password.
 * 
 * Required Environment Variables:
 * - APPWRITE_API_KEY: Server API key with `users.read` and `users.write` scopes.
 * - APPWRITE_FUNCTION_PROJECT_ID: (Auto-injected by Appwrite)
 * - APPWRITE_FUNCTION_ENDPOINT: (Auto-injected by Appwrite)
 */
module.exports = async function (context) {
  const req = context.req;
  const res = context.res;
  const log = context.log;
  const error = context.error;

  // Initialize Appwrite Server SDK
  const client = new sdk.Client()
    .setEndpoint('https://appwrite.aigenxt.com/v1')
    .setProject('6972fc1c001816b0de41')
    .setKey(process.env.API_KEY);

  const users = new sdk.Users(client);

  // Parse request body
  let body;
  try {
    body = typeof req.body === 'string' ? JSON.parse(req.body) : req.body;
  } catch (err) {
    return res.json({ success: false, message: "Invalid request body." }, 400);
  }

  const { email, password } = body;

  if (!email || !password) {
    return res.json({ success: false, message: "Missing email or password." }, 400);
  }

  try {
    // 1. Find user by email
    const userList = await users.list([
      sdk.Query.equal("email", email)
    ]);

    if (userList.total === 0) {
      return res.json({ success: false, message: "User not found." }, 404);
    }

    const userId = userList.users[0].$id;

    // 2. Update user's password using the Server SDK (bypasses current password requirement)
    await users.updatePassword(userId, password);

    log(`Successfully updated password for user: ${userId}`);
    return res.json({ success: true, message: "Password updated successfully." });
    
  } catch (err) {
    error(`Error updating password: ${err.message}`);
    return res.json({ success: false, message: err.message }, 500);
  }
};
