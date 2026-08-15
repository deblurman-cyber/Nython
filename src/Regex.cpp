
#include "Regex.hpp"

namespace nython::kernel {

  Regex::Regex() : pattern_{}, flags_{}, indexes_{}, regex_{} {}

  // Constructor for a regular expression
  Regex::Regex(std::string pattern, RegexFlags flags) : pattern_(pattern), flags_{flags}, indexes_{}, regex_{pattern} {
  }

  // Copy constructor for a regular expression
  Regex::Regex(const Regex& other) : Regex(other.pattern_, other.flags_) {
  }

  // Destructor for a regular expression
  Regex::~Regex() {
  }

  // Return the pattern of the regular expression
  std::string Regex::pattern() {
    return pattern_;
  }

  // Return the index of the numbered group corresponding to a named group
  size_t Regex::index(std::string name) {
    std::unordered_map<std::string, size_t>::iterator it;
    if ((it = indexes_.find(name)) != indexes_.end())
      return std::get<1>(*it);
    else
      throw RegexException(fmt::format("Cannot find named capture group '{}' in pattern '{}'", name, pattern_));
  }

  // Search for the regular expression in a string
  RegexMatch Regex::match(std::string subject, size_t pos, RegexMatchFlags flags) {
    // Fetch the groups of the match
    std::vector<RegexGroup> groups;
    // Create and return the result
    RegexMatch result(this, subject, groups);
    return result;
  }

  // Search for all non-overlapping occurrences of the regular expression in a string
  std::vector<RegexMatch> Regex::match_all(std::string subject, size_t pos) {
    std::vector<RegexMatch> matches;

    auto m = match(subject, pos);
    while (m.success())
    {
      matches.push_back(m);
      pos = m.end();
      m = match(subject, pos);
    }

    return matches;
  }

  // Substitute all non-overlapping occurrences of the regular expression in a string
  std::string Regex::substitute(std::string subject, std::string replacement) {
    std::string result;
    return result;
  }

  // Split a string by the occurrences of the regular expression
  std::vector<std::string> Regex::split(std::string subject) {
    auto m = match(subject);
    if (!m.success())
      return std::vector<std::string>({subject});

    std::vector<std::string> parts;

    size_t pos = 0;
    while (m.success())
    {
      parts.push_back(std::string(subject, pos, m.start() - pos));
      pos = m.end();
      m = match(subject, pos);
    }

    return parts;
  }

  // --------------------------------------------------------------------------

  // Constructor
  RegexGroup::RegexGroup(Regex* pattern, std::string subject, size_t start, size_t end) : pattern_(pattern), subject_(subject), start_(start), end_(end) {
  }

  // Return the rregular expression of the capture group
  Regex* RegexGroup::pattern() {
    return pattern_;
  }

  // Return the subject of the capture group
  std::string RegexGroup::subject() {
    return subject_;
  }

  // Return if the capture group has matched anything
  bool RegexGroup::success() {
    return true;
  }

  // Return the start offset of the substring matched by the capture group
  size_t RegexGroup::start() {
    return start_;
  }

  // Return the end offset of the substring matched by the capture group
  size_t RegexGroup::end() {
    return end_;
  }

  // Return the length of the substring matched by the capture group
  size_t RegexGroup::length() {
    return end_ - start_;
  }

  // Return the substring matched by a capture group
  std::string RegexGroup::value() {
    return success() ? std::string(subject_, start_, end_ - start_) : "";
  }

  // --------------------------------------------------------------------------

  // Constructor for a regular expression match
  RegexMatch::RegexMatch(Regex* pattern, std::string subject, std::vector<RegexGroup> groups) : pattern_(pattern), subject_(subject), groups_(groups) {
  }

  // Return the rregular expression of the regular expression match
  Regex* RegexMatch::pattern()
  {
    return pattern_;
  }

  // Return the subject of the regular expression match
  std::string RegexMatch::subject()
  {
    return subject_;
  }

  // Return if the regular expression match has matched anything
  bool RegexMatch::success()
  {
    return groups_.size() > 0;
  }

  // Return a numbered capture group of the regular expression match
  RegexGroup RegexMatch::group(int index)
  {
    if (index < (int)groups_.size())
      return groups_[index];
    else
      throw RegexException(fmt::format("Cannot find capture group {} in pattern", index));
  }

  // Return a named capture group of the regular expression match
  RegexGroup RegexMatch::group(std::string name)
  {
    return group(pattern_->index(name));
  }

  // Return the prefix of the regular expression match
  RegexGroup RegexMatch::prefix()
  {
    if (success())
      return RegexGroup(pattern_, subject_, 0, group(0).start());
    else
      return RegexGroup(pattern_, subject_, REGEX_UNSET, REGEX_UNSET);
  }

  // Return the prefix of the regular expression match
  RegexGroup RegexMatch::suffix()
  {
    if (success())
      return RegexGroup(pattern_, subject_, group(0).end(), subject_.length());
    else
      return RegexGroup(pattern_, subject_, REGEX_UNSET, REGEX_UNSET);
  }
}

