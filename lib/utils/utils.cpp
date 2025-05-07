#include "utils/utils.h"

// Helper function to initialize the locale.
// Placed in an anonymous namespace or as a static member if preferred.
namespace {
  std::locale create_default_microtex_locale() {
  #if defined(__WIN32__)
      // Windows uses "C" in your original code, which is safe.
      // Or, if you wanted an English locale on Windows, you might try "en-US" or "English_United States.1252"
      // but "C" is the simplest and most portable if you don't need specific Windows collation for "default".
      try {
          return std::locale("C");
      } catch (const std::runtime_error& e) {
          std::cerr << "PANIC: Could not construct 'C' locale on Windows: " << e.what() << std::endl;
          return std::locale::classic(); // Absolute fallback
      }
  #else // Non-Windows (Linux, macOS, iOS, etc.)
      // Try the most specific first, then fall back
      try {
          return std::locale("en_US.UTF-8");
      } catch (const std::runtime_error& e1) {
          // Optional: Log the warning if you have a logging mechanism
          // std::cerr << "Warning: Could not create locale 'en_US.UTF-8' (" << e1.what() << "), trying 'en_US'." << std::endl;
          try {
              return std::locale("en_US");
          } catch (const std::runtime_error& e2) {
              // std::cerr << "Warning: Could not create locale 'en_US' (" << e2.what() << "), trying 'en'." << std::endl;
              try {
                  return std::locale("en");
              } catch (const std::runtime_error& e3) {
                  // std::cerr << "Warning: Could not create locale 'en' (" << e3.what() << "), falling back to classic 'C' locale." << std::endl;
                  return std::locale::classic(); // Safest fallback, ASCII behavior
              }
          }
      }
  #endif
  }
  } // anonymous namespace

  const std::locale& microtex::defaultLocale() {
    static const std::locale locale = create_default_microtex_locale();
    return locale;
}

bool microtex::isUnicodeLower(c32 code) {
  // the type-cast is necessary, or a std::bad_cast will be thrown,
  // because std::toupper is a template function
  return std::islower((wchar_t)code, defaultLocale());
}

bool microtex::isUnicodeDigit(c32 code) {
  return std::isdigit((wchar_t)code, defaultLocale());
}

microtex::c32 microtex::toUnicodeUpper(c32 code) {
  return std::toupper((wchar_t)code, defaultLocale());
}

microtex::c32 microtex::toUnicodeLower(c32 code) {
  return std::tolower((wchar_t)code, defaultLocale());
}

int microtex::binIndexOf(int count, const std::function<int(int)>& compare, bool returnClosest) {
  if (count == 0) return -1;
  int l = 0, h = count - 1;
  while (l <= h) {
    const int m = l + ((h - l) >> 1);
    const int cmp = compare(m);
    if (cmp == 0) return m;
    cmp < 0 ? h = m - 1 : l = m + 1;
  }
  return returnClosest ? std::max(0, l - 1) : -1;
}
