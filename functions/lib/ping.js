"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.ping = void 0;
exports.pingHandler = pingHandler;
const https_1 = require("firebase-functions/v2/https");
function pingHandler(request) {
    if (!request.auth) {
        throw new https_1.HttpsError("unauthenticated", "Sign in required.");
    }
    return { message: `pong, ${request.auth.uid}` };
}
exports.ping = (0, https_1.onCall)(pingHandler);
//# sourceMappingURL=ping.js.map