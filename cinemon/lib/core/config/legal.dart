/// The Terms of Use and Privacy Policy everyone agrees to (migration 021).
///
/// Bump [kTermsVersion] whenever either changes in a way people should see:
/// everyone is shown the agree screen again on their next launch. Keep it
/// equal to the "Last updated" date on the website's terms page.
const kTermsVersion = '2026-09-24';

const kSiteUrl = 'https://35mm.contact';
const kTermsUrl = '$kSiteUrl/terms';
const kPrivacyUrl = '$kSiteUrl/privacy';
const kSupportUrl = '$kSiteUrl/support';

/// The youngest anyone can be to use 35mm (Terms; COPPA).
const kMinimumAge = 13;

/// Under this, an account starts private.
const kAdultAge = 18;

/// Whole years between [birth] and [now].
int ageOn(DateTime birth, DateTime now) {
  var years = now.year - birth.year;
  if (now.month < birth.month ||
      (now.month == birth.month && now.day < birth.day)) {
    years -= 1;
  }
  return years;
}
