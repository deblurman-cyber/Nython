#pragma once

#include <unordered_map>
#include "Except.hpp"
#include "Definitions.hpp"

/**
* Check if a text matches a text pattern: std::regex_match
* Search for a text pattern in a text: std::regex_search
* Replace a text pattern with a text: std::regex_replace
* Iterate through all text patterns in a text: std::regex_iterator and std::regex_token_iterator
*/

namespace nython::kernel {

  using nython::exception::Exception;

  // Forward declarations
  class Regex;
  class RegexMatch; /// std::regex_match
  class RegexGroup; /// std::regex_iterator
  class RegexException;


  // Enum that defines flags for a regular expression
  enum RegexFlags : int {
    REGEX_BASIC       = 0,
    REGEX_COLLATE     = 1 << 1,   // Make \d, \w, etc. perform ASCII-only matching instead of full Unicode matching.
    REGEX_IGNORECASE  = 1 << 2,   // Perform case-insensitive matching; expressions like [A-Z] will also match lowercase letters.
    REGEX_OPTIMIZE    = 1 << 3,   // Make the '^' character match at the beginning of each line and the '$' character match at the end of each line.
    REGEX_NOSUBS      = 1 << 4,   // Make the '.' character match any character at all, including a newline; without this flag, '.' will match anything except a newline.
    REGEX_EXTENDED    = 1 << 5,   // Ignore whitespace and comments preceded by '#'.
    REGEX_ECMA_SCRIPT = 1 << 6,   // Ignore whitespace and comments preceded by '#'.
    REGEX_AWK         = 1 << 7,   // Ignore whitespace and comments preceded by '#'.
    REGEX_GREP        = 1 << 8,   // Ignore whitespace and comments preceded by '#'.
    REGEX_EGREP       = 1 << 9,   // Ignore whitespace and comments preceded by '#'.
  };

  // Enum that defines flags for a regular expression match
  enum RegexMatchFlags : int {
    REGEX_MATCH_NONE      = 0,
    REGEX_MATCH_AT_BEGIN  = 1 << 1,   // Pattern can match only at the beginning of the subject string
    REGEX_MATCH_AT_END    = 1 << 2,   // Pattern can match only at the end of the subject string
  };

  #define REGEX_UNSET -1


  // Class that defines a regular expression
  class Regex {

    private:
      // The pattern of the regular expression
      std::string pattern_;

      // flags for matching or searching
      RegexFlags flags_;

      // The named capture groups of the regular expression mapped to the corresponding numbered group
      std::unordered_map<std::string, size_t> indexes_;

      // c++ regex
      std::regex regex_;


    public:
      // Constructor
      Regex();
      Regex(std::string pattern, RegexFlags flags = REGEX_BASIC);

      // Copy constructor
      Regex(const Regex& other);

      // Destructor
      ~Regex();

      // Assign a pattern and a flag
      Regex& assign(const Regex& other);
      Regex& assign(std::string pattern, RegexFlags flags = REGEX_BASIC);
      Regex& operator=(std::string pattern);
      Regex& operator=(const Regex& other);

      // Match count
      unsigned count() const {
        return regex_.mark_count();
      }

      // Return the pattern of the regular expression
      std::string pattern();

      // Return the index of the numbered group corresponding to a named group
      size_t index(std::string name);

      // Search for the regular expression in a string
      RegexMatch match(std::string subject, size_t pos = 0, RegexMatchFlags flags = REGEX_MATCH_NONE);

      // Search for all non-overlapping occurrences of the regular expression in a string
      std::vector<RegexMatch> match_all(std::string subject, size_t pos = 0);

      // Substitute all non-overlapping occurrences of the regular expression in a string
      std::string substitute(std::string subject, std::string replacement);

      // Split a string by the occurrences of the regular expression
      std::vector<std::string> split(std::string subject);
  };


  // Class that defines a capture group in a regular expression match
  class RegexGroup {
  public:
    RegexGroup(const RegexGroup&) = default;
    RegexGroup& operator=(const RegexGroup&) = default;

    private:
      // The regular expression of the capture group
      Regex* pattern_;

      // The subject of the capture group
      std::string subject_;

      // The start offset of the substring matched by the capture group
      size_t start_;

      // The end offset of the substring matched by the capture group
      size_t end_;


    public:
      // Constructor
      RegexGroup(Regex* pattern, std::string subject, size_t start, size_t end);

      // Return the regular expression of the capture group
      Regex* pattern();

      // Return the subject of the capture group
      std::string subject();

      // Return if the capture group has matched anything
      bool success();

      // Return the properties of the substring matched by the capture group
      size_t start();
      size_t end();
      size_t length();
      std::string value();
  };


  // Class that defines a regular expression match
  class RegexMatch {
  public:
    RegexMatch(const RegexMatch&) = default;
    RegexMatch& operator=(const RegexMatch&) = default;

    private:
      // The regular expression of the regular expression match
      Regex* pattern_;

      // The subject of the regular expression match
      std::string subject_;

      // The capture groups of the regular expression match
      std::vector<RegexGroup> groups_;


    public:
      // Constructor
      RegexMatch(Regex* pattern, std::string subject, std::vector<RegexGroup> groups);

      // Return the regular expression of the regular expression match
      Regex* pattern();

      // Return the subject of the regular expression match
      std::string subject();

      // Return if the regular expression match has matched anything
      bool success();

      // Return a capture group of the regular expression match
      RegexGroup group(int index = 0);
      RegexGroup group(std::string name);

      // Return the prefix and suffix of the regular expression match
      RegexGroup prefix();
      RegexGroup suffix();

      // Return the properties of substring matched by the regular expression match
      inline size_t start() { return group().start(); }
      inline size_t end() { return group().end(); }
      inline size_t length() { return group().length(); }
      inline std::string value() { return group().value(); }
  };


  // Exception thrown when processing a regular expression fails
  class RegexException : public Exception {
    public:
      inline RegexException(std::string message, Exception* previous) : Exception(message, previous) {}
      inline RegexException(std::string message) : Exception(message, nullptr) {}
      virtual ~RegexException() {}
  };
}

