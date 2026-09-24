# Email templates

Paste these into Supabase → Authentication → Emails (ADR 0004 D4). The app asks for the 6-digit code, so the templates show `{{ .Token }}` and deliberately carry **no link**: mail apps prefetch links, and a prefetched link uses up the same one-time token the code depends on.

| Template in Supabase | File | Subject |
|---|---|---|
| Confirm signup | `confirm_signup.html` | `Your 35mm code: {{ .Token }}` |
| Reset password | `reset_password.html` | `Your 35mm code: {{ .Token }}` |

Also in Authentication → Providers → Email: **Email OTP length 6**, **Email OTP expiration 3600** seconds.
