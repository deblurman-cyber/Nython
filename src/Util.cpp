#pragma GCC diagnostic push
#pragma GCC diagnostic ignored "-Wshadow"
#include "Util.hpp"
#include "Regex.hpp"

namespace nython::utils {

std::map<char,string> OctMap = {
    {'0',"000"},{'1',"001"},
    {'2',"010"},{'3',"011"},
    {'4',"100"},{'5',"101"},
    {'6',"110"},{'7',"111"},
};

std::map<string,char> OctToNumMap = {
    {"000",'0'},{"001",'1'},
    {"010",'2'},{"011",'3'},
    {"100",'4'},{"101",'5'},
    {"110",'6'},{"111",'7'},
};


std::map<char,string> HexMap = {
    {'0',"0000"},{'1',"0001"},
    {'2',"0010"},{'3',"0011"},
    {'4',"0100"},{'5',"0101"},
    {'6',"0110"},{'7',"0111"},
    {'8',"1000"},{'9',"1001"},
    {'a',"1010"},{'b',"1011"},
    {'c',"1100"},{'d',"1101"},
    {'e',"1110"},{'f',"1111"},
};


std::string dec(const string& v){
    if(v[1]=='x'||v[1]=='X') return __string__(__int__(bin(v)));
    if(v[1]=='o'||v[1]=='O') return __string__(__int__(bin(v)));
    return __string__(__int__(v));
}

bigint __int__(const string& v){
    bigint val = 0;
    long len = v.size();
    for(long i = 0;i<len;i++){
        if(v[i]=='1') val = long(std::pow(2,len-i-1))+val;
    }
    return val;
}

long double __float__(const string& v){
    long double val = 0;
    long len = v.size();
    for(long i = 0;i<len;i++){
        if(v[i]=='1') val = pow(2,len-i-1)+val;
    }
    return val;
}

string __string__(bigint v){
    stringstream ret;
    ret<<v;
    return ret.str();
}

string __string__(long double v){
    stringstream ret;
    ret<<v;
    return ret.str();
}

inline void format_float(char *buf, size_t buflen,Value* v, int precision) {
	/*register*/ char *cp;
	char format[32];
	int i;
	/**
       Subroutine for float_repr and float_print.
	   We want float numbers to be recognizable as such,
	   i.e., they should contain a decimal point or an exponent.
	   However, %g may print the number as an integer;
	   in such cases, we append ".0" to the string.
    */

	assert(v!=nullptr);
	_snprintf(format, 32, "%%.%ig", precision);
	_ascii_formatd(buf, buflen, format, v->value.d);
	cp = buf;
	if(*cp == '-') cp++;
	for(; *cp != '\0'; cp++){
		/* Any non-digit means it's not an integer; this takes care of NAN and INF as well. */
		if(!isdigit(*cp)) break;
	}
	if(*cp == '\0'){
		*cp++ = '.';
		*cp++ = '0';
		*cp++ = '\0';
		return;
	}
	/** Checking the next three chars should be more than enough to
	 * detect inf or nan, even on Windows. We check for inf or nan
	 * at last because they are rare cases.
	 */
	for(i=0; *cp != '\0' && i<3; cp++, i++){
		if(isdigit(*cp) || *cp == '.') continue;
		/* found something that is neither a digit nor point
		 * it might be a NaN or INF
		 */
        if(IS_NAN(v->value.d)){
			strcpy(buf, "nan");
		}else if(IS_INFINITY(v->value.d)){
			cp = buf;
			if(*cp == '-')
				cp++;
			strcpy(cp, "inf");
		}
		break;
	}
}

inline std::string format(Value* v,int precision){
    char buffer[100];
    format_float(buffer,sizeof(buffer),v,precision);
    return buffer;
}

inline std::string escapeSpecialXMLChars(string s){
    string escapedString = replace(s,"&", "&amp;");
    escapedString = replace(escapedString,"<", "&lt;");
    escapedString = replace(escapedString,">", "&gt;");
    escapedString = replace(escapedString,"\"", "&quot;");
    escapedString = replace(escapedString,"'", "&#39;");
    return escapedString;
}

using nython::kernel::Regex;
using nython::kernel::RegexMatchFlags;

std::wstring_convert<convert_t, wchar_t> strconverter;

std::string unescape(std::string string, StringEscapeType type) {
    auto escape_pattern = Regex("\\\\(?:(u\\{([0-9A-Fa-f]{1,6})\\})|(\")|(\')|([\\btnfr])|.)");
    auto escape_matches = escape_pattern.match_all(string);
    std::string result(string);

    for (auto match : escape_matches)
    {
      std::string result;
      if (match.group(1).success())
        result = rune_pack_to_str(parse_rune(match.group(2).value()));
      else if (match.group(3).success() && type == StringEscapeType::DOUBLE_QUOTED)
        result = match.group(3).value();
      else if (match.group(4).success() && type == StringEscapeType::SINGLE_QUOTED)
        result = match.group(4).value();
      else if (match.group(5).success())
        result = match.group(5).value();
      else
        throw std::invalid_argument(fmt::format("Invalid escape sequence '{}'", match.value()));

      string = match.prefix().value() + result + match.suffix().value();
    }
    return string;
}

// Parse a string as an integer
int64_t parse_int(std::string string) {
    // Remove thousand separators from the string
    string = Regex("_").substitute(string, "");

    // Check if the string contains a hexadecimal integer
    auto is_hex_match = Regex("0[Xx]").match(string, 0, RegexMatchFlags::REGEX_MATCH_AT_BEGIN);

    // Parse the string as an integer
    size_t end_index;
    auto int_value = (int64_t)std::stoll(string, &end_index, is_hex_match.success() ? 16 : 10);
    if (end_index != string.length())
      throw std::invalid_argument(fmt::format("Unexpected character '{}' in integer", string.substr(end_index, 1)));

    // Return the parsed integer
    return int_value;
}

// Parse a string as a real
double parse_real(std::string string) {
    // Remove thousand separators from the string
    string = Regex("_").substitute(string, "");

    // Parse the string as a real
    size_t end_index;
    double real_value = (double)std::stod(string, &end_index);
    if (end_index != string.length())
      throw std::invalid_argument(fmt::format("Unexpected character '{}' in real", string.substr(end_index, 1)));

    // Return the parsed real
    return real_value;
}

// Parse a string as a rune
uint32_t parse_rune(std::string string) {
    // Unescape the string
    string = unescape(string, StringEscapeType::SINGLE_QUOTED);

    // Parse the rune literal
    auto runes = rune_unpack_from_str(string);
    if (runes.size() < 1)
      throw std::invalid_argument("Missing code point in rune");
    if (runes.size() > 1)
      throw std::invalid_argument("Unexpected extra code point(s) in rune");
    auto rune_value = runes.front();

    // Return the parsed rune
    return rune_value;
}

// Parse a string a a C-string
const char* parse_string(std::string string) {
    // Unescape the string
    string = unescape(string, StringEscapeType::DOUBLE_QUOTED);

    // Return the parsed C-string
    return string.c_str();
}

}

#pragma GCC diagnostic pop
