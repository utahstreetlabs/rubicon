# Define several general exceptions to handle various auth or session issues that might be raised.
# If possible, translate specific exceptions (e.g. Mogli client exceptions for Facebook) to these
# for handling by Brooklyn.

# Permission for an activity on an external network is missing.
class MissingPermission < Exception; end

# A session has been invalidated due to user activity such as password change
class InvalidSession < Exception; end

# An action taken is not allowed because of the receiving user's permissions.
# Facebook returns a "user not visible" error you try, for example, to post to a user's wall
# and that user does not allow wall posts.
class ActionNotAllowed < Exception; end

# The action being taken is refused due to rate limiting.
class RateLimited < Exception; end

# The access token used for the session, such as the OAuth token, is invalid.  Can
# occur due to session timeout for the token.
class AccessTokenInvalid < Exception; end

# User data for the profile was missing; this could be the result of a mismatched network type
# and profile, which we've seen in mongo.
class MissingUserData < Exception; end
