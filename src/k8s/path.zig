const std = @import("std");

/// Reject a name, namespace, or other value interpolated into one URL path segment
/// unless it is safe there, mirroring client-go's `IsValidPathSegmentName`.
///
/// Rejected: empty, `.`, `..`, and any value containing `/`, `%`, `?`, `#`, a
/// control byte, a space, or DEL. Those either change which resource or query the
/// request addresses (`../secrets/x`, `a%2Fb`, `a?watch=1`) or split the HTTP
/// request line (CR/LF, space).
pub fn validatePathSegment(segment: []const u8) error{InvalidPathSegment}!void {
    if (!isValidPathSegment(segment)) return error.InvalidPathSegment;
}

/// Boolean form of `validatePathSegment`.
pub fn isValidPathSegment(segment: []const u8) bool {
    if (segment.len == 0) return false;
    if (std.mem.eql(u8, segment, ".") or std.mem.eql(u8, segment, "..")) return false;
    for (segment) |byte| {
        switch (byte) {
            0...0x20, 0x7f, '/', '%', '?', '#' => return false,
            else => {},
        }
    }
    return true;
}

/// Reject a value that would be unsafe inside an HTTP header: CR, LF, NUL and the
/// other control bytes except horizontal tab, and DEL.
pub fn validateHeaderValue(value: []const u8) error{InvalidHeaderValue}!void {
    if (!isSafeHeaderValue(value)) return error.InvalidHeaderValue;
}

/// `validateHeaderValue` for a bearer token, with an error that names the token.
pub fn validateBearerToken(token: []const u8) error{InvalidBearerToken}!void {
    if (!isSafeHeaderValue(token)) return error.InvalidBearerToken;
}

fn isSafeHeaderValue(value: []const u8) bool {
    for (value) |byte| {
        if ((byte < 0x20 and byte != '\t') or byte == 0x7f) return false;
    }
    return true;
}

/// Last line of defence before a URL reaches the HTTP request line: a space, CR,
/// LF, or other control byte there would split or extend the request.
pub fn validateRequestUrl(url: []const u8) error{InvalidRequestUrl}!void {
    for (url) |byte| {
        if (byte < 0x21 or byte == 0x7f) return error.InvalidRequestUrl;
    }
}
