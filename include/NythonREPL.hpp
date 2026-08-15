#pragma once
#include <string>
#include <vector>
#include <functional>
#include <cstring>
#include <algorithm>
#include <set>

// Platform compat (winsock, dirent, ssize_t, etc.) included via NythonExecutor.hpp
#ifndef _WIN32
  #include <termios.h>
  #include <sys/ioctl.h>
#endif
#ifndef STDIN_FILENO
  #define STDIN_FILENO  0
  #define STDOUT_FILENO 1
#endif

namespace nython { namespace repl_engine {

static inline void w_raw(const char* s, size_t n) {
#ifdef _WIN32
    DWORD written;
    WriteConsoleA(GetStdHandle(STD_OUTPUT_HANDLE), s, (DWORD)n, &written, NULL);
#else
    ssize_t r = write(STDOUT_FILENO, s, n); (void)r;
#endif
}
static inline void w_str(const std::string& s) {
    w_raw(s.c_str(), s.size());
}

struct Color {
    static constexpr const char* RESET   = "\x1b[0m";
    static constexpr const char* BOLD    = "\x1b[1m";
    static constexpr const char* DIM     = "\x1b[2m";
    static constexpr const char* RED     = "\x1b[31m";
    static constexpr const char* GREEN   = "\x1b[32m";
    static constexpr const char* YELLOW  = "\x1b[33m";
    static constexpr const char* BLUE    = "\x1b[34m";
    static constexpr const char* MAGENTA = "\x1b[35m";
    static constexpr const char* CYAN    = "\x1b[36m";
    static constexpr const char* BRIGHT_YELLOW = "\x1b[93m";
};

static const std::set<std::string> KW = {
    "if","else","elif","for","while","def","class","return",
    "import","from","as","try","except","finally","raise",
    "break","continue","and","or","not","in","is",
    "var","true","false","none","lambda","assert",
    "switch","case","default","do","end","enum","repeat"
};
static const std::set<std::string> BI = {
    "print","len","type","str","int","float","bool",
    "range","abs","min","max","pow","sqrt","hex","bin",
    "chr","ord","input","enumerate","zip","sorted","reversed",
    "sum","round","read_file","write_file","file_exists",
    "sin","cos","tan","log","floor","ceil"
};

class Highlighter {
public:
    static std::string highlight(const std::string& line) {
        std::string out;
        size_t i = 0, n = line.size();
        while (i < n) {
            if (line[i] == '#') {
                out += Color::DIM; out += line.substr(i); out += Color::RESET; break;
            }
            if (line[i] == '"' || line[i] == '\'') {
                char q = line[i]; out += Color::YELLOW; out += q; i++;
                while (i < n && line[i] != q) {
                    if (line[i] == '\\' && i+1 < n) out += line[i++];
                    out += line[i++];
                }
                if (i < n) out += line[i++];
                out += Color::RESET; continue;
            }
            if (isdigit(line[i]) || (line[i] == '.' && i+1 < n && isdigit(line[i+1]))) {
                out += Color::MAGENTA;
                while (i < n && (isdigit(line[i]) || line[i] == '.' || line[i] == 'x' ||
                       line[i] == 'b' || (line[i] >= 'a' && line[i] <= 'f')))
                    out += line[i++];
                out += Color::RESET; continue;
            }
            if (isalpha(line[i]) || line[i] == '_') {
                std::string w;
                while (i < n && (isalnum(line[i]) || line[i] == '_')) w += line[i++];
                if (KW.count(w)) { out += Color::BOLD; out += Color::BLUE; out += w; out += Color::RESET; }
                else if (BI.count(w)) { out += Color::CYAN; out += w; out += Color::RESET; }
                else out += w;
                continue;
            }
            if (line[i]=='+'||line[i]=='-'||line[i]=='*'||line[i]=='/'||line[i]=='%'||
                line[i]=='='||line[i]=='<'||line[i]=='>'||line[i]=='!') {
                out += Color::RED; out += line[i++];
                if (i < n && (line[i]=='='||line[i]=='*'||line[i]=='/')) out += line[i++];
                out += Color::RESET; continue;
            }
            if (line[i]=='('||line[i]==')'||line[i]=='['||line[i]==']'||line[i]=='{'||line[i]=='}') {
                out += Color::BRIGHT_YELLOW; out += line[i++]; out += Color::RESET; continue;
            }
            out += line[i++];
        }
        return out;
    }
};

class Terminal {
#ifdef _WIN32
    DWORD orig_mode_ = 0;
    HANDLE hIn_ = INVALID_HANDLE_VALUE;
#else
    struct termios orig_{};
#endif
    bool raw_ = false;
public:
    void enableRaw() {
        if (raw_) return;
#ifdef _WIN32
        hIn_ = GetStdHandle(STD_INPUT_HANDLE);
        GetConsoleMode(hIn_, &orig_mode_);
        DWORD mode = orig_mode_;
        mode &= ~(ENABLE_ECHO_INPUT | ENABLE_LINE_INPUT | ENABLE_PROCESSED_INPUT);
        mode |= ENABLE_VIRTUAL_TERMINAL_INPUT;
        SetConsoleMode(hIn_, mode);
        // Enable VT processing on output
        HANDLE hOut = GetStdHandle(STD_OUTPUT_HANDLE);
        DWORD outMode;
        GetConsoleMode(hOut, &outMode);
        SetConsoleMode(hOut, outMode | ENABLE_VIRTUAL_TERMINAL_PROCESSING);
#else
        tcgetattr(STDIN_FILENO, &orig_);
        struct termios r = orig_;
        r.c_iflag &= ~(unsigned)(BRKINT|ICRNL|INPCK|ISTRIP|IXON);
        r.c_oflag &= ~(unsigned)(OPOST);
        r.c_cflag |= (unsigned)(CS8);
        r.c_lflag &= ~(unsigned)(ECHO|ICANON|IEXTEN|ISIG);
        r.c_cc[VMIN]=1; r.c_cc[VTIME]=0;
        tcsetattr(STDIN_FILENO, TCSAFLUSH, &r);
#endif
        raw_ = true;
    }
    void disableRaw() {
        if (!raw_) return;
#ifdef _WIN32
        if (hIn_ != INVALID_HANDLE_VALUE) SetConsoleMode(hIn_, orig_mode_);
#else
        tcsetattr(STDIN_FILENO, TCSAFLUSH, &orig_);
#endif
        raw_ = false;
    }
    ~Terminal() { disableRaw(); }

    enum Key {
        K_EOF=-1, K_ENTER=10, K_TAB=9,
        K_BS=127, K_BS2=8,
        K_CA=1,K_CB=2,K_CC=3,K_CD=4,K_CE=5,K_CF=6,K_CK=11,K_CL=12,
        K_CN=14,K_CP=16,K_CU=21,K_CW=23,
        K_UP=1001,K_DOWN=1002,K_RIGHT=1003,K_LEFT=1004,
        K_HOME=1005,K_END=1006,K_DEL=1007
    };

    int readKey() {
        char c;
#ifdef _WIN32
        DWORD read_count;
        if (!ReadConsoleA(hIn_, &c, 1, &read_count, NULL) || read_count == 0) return K_EOF;
        if (c == '\r') return K_ENTER;
        if (c == '\x1b') {
            char s[3];
            if (!ReadConsoleA(hIn_, &s[0], 1, &read_count, NULL) || read_count == 0) return '\x1b';
            if (!ReadConsoleA(hIn_, &s[1], 1, &read_count, NULL) || read_count == 0) return '\x1b';
#else
        if (read(STDIN_FILENO, &c, 1) != 1) return K_EOF;
        if (c == '\x1b') {
            char s[3];
            if (read(STDIN_FILENO, &s[0], 1) != 1) return '\x1b';
            if (read(STDIN_FILENO, &s[1], 1) != 1) return '\x1b';
#endif
            if (s[0] == '[') {
                if (s[1] >= '0' && s[1] <= '9') {
#ifdef _WIN32
                    if (!ReadConsoleA(hIn_, &s[2], 1, &read_count, NULL) || read_count == 0) return '\x1b';
#else
                    if (read(STDIN_FILENO, &s[2], 1) != 1) return '\x1b';
#endif
                    if (s[2] == '~') {
                        if (s[1]=='1'||s[1]=='7') return K_HOME;
                        if (s[1]=='3') return K_DEL;
                        if (s[1]=='4'||s[1]=='8') return K_END;
                    }
                    return '\x1b';
                }
                if (s[1]=='A') return K_UP;
                if (s[1]=='B') return K_DOWN;
                if (s[1]=='C') return K_RIGHT;
                if (s[1]=='D') return K_LEFT;
                if (s[1]=='H') return K_HOME;
                if (s[1]=='F') return K_END;
            } else if (s[0]=='O') {
                if (s[1]=='H') return K_HOME;
                if (s[1]=='F') return K_END;
            }
            return '\x1b';
        }
        return (unsigned char)c;
    }
};

class ContinuationDetector {
public:
    static bool hasUnbalanced(const std::string& code) {
        int p=0, b=0, c=0;
        bool in_str=false; char sc=0;
        for (size_t i=0; i<code.size(); i++) {
            char ch = code[i];
            if (in_str) { if (ch==sc && (i==0||code[i-1]!='\\')) in_str=false; continue; }
            if (ch=='"'||ch=='\'') { in_str=true; sc=ch; continue; }
            if (ch=='#') { while (i<code.size()&&code[i]!='\n') i++; continue; }
            if (ch=='(') p++; else if (ch==')') p--;
            if (ch=='[') b++; else if (ch==']') b--;
            if (ch=='{') c++; else if (ch=='}') c--;
        }
        return p>0||b>0||c>0;
    }

    static bool endsWithOpener(const std::string& line) {
        auto p = line.find_last_not_of(" \t\r\n");
        if (p == std::string::npos) return false;
        std::string t = line.substr(0, p+1);
        if (t.empty()) return false;
        if (t.back()==':'||t.back()=='{'||t.back()=='\\') return true;
        if (t.size()>=2 && t.substr(t.size()-2)=="do") {
            if (t.size()==2||t[t.size()-3]==' '||t[t.size()-3]==')') return true;
        }
        return false;
    }

    static int getIndent(const std::string& line) {
        int n=0;
        for (char c:line) { if(c==' ') n++; else if(c=='\t') n+=4; else break; }
        return n;
    }

    static bool isEmpty(const std::string& line) {
        return line.find_first_not_of(" \t\r\n") == std::string::npos;
    }

    static bool needsContinuation(const std::vector<std::string>& lines) {
        if (lines.empty()) return false;
        std::string full;
        for (auto& l:lines) full += l + "\n";
        if (hasUnbalanced(full)) return true;
        if (endsWithOpener(lines.back())) return true;
        // If last line is indented and non-empty, we're still in a block
        if (lines.size()>1 && !isEmpty(lines.back()) && getIndent(lines.back())>0) return true;
        // If last line starts with elif/else/except/finally/case/default, continue
        auto lt = lines.back(); auto p = lt.find_first_not_of(" \t");
        if (p != std::string::npos) {
            std::string first_word;
            for (size_t i=p; i<lt.size() && (isalnum(lt[i])||lt[i]=='_'); i++) first_word+=lt[i];
            if (first_word=="elif"||first_word=="else"||first_word=="except"||
                first_word=="finally"||first_word=="case"||first_word=="end") return true;
        }
        return false;
    }

    static int suggestIndent(const std::vector<std::string>& lines) {
        if (lines.empty()) return 0;
        int base = getIndent(lines.back());
        if (endsWithOpener(lines.back())) return base + 4;
        return base;
    }
};

// ─── The actual multiline REPL editor ──────────────────────────────────────
class MultilineEditor {
    Terminal term_{};
    std::vector<std::string> history_{};
    int hist_idx_ = 0;

    std::vector<std::string> lines_{};
    int cl_ = 0; // cursor line
    int cc_ = 0; // cursor col

    void setCursorCol(int col) {
        char buf[32];
        if (col > 0) {
            int len = snprintf(buf, sizeof(buf), "\r\x1b[%dC", col);
            w_raw(buf, (size_t)len);
        } else {
            w_raw("\r", 1);
        }
    }

    void refreshAll() {
        // Move up to line 0
        if (cl_ > 0) {
            char buf[32];
            int len = snprintf(buf, sizeof(buf), "\x1b[%dA", cl_);
            w_raw(buf, (size_t)len);
        }
        w_raw("\r", 1);
        // Draw all lines
        for (int i = 0; i < (int)lines_.size(); i++) {
            w_raw("\x1b[2K", 4);
            w_str(i==0 ? "\x1b[1;32m>>> \x1b[0m" : "\x1b[1;33m... \x1b[0m");
            w_str(Highlighter::highlight(lines_[i]));
            if (i < (int)lines_.size()-1) w_raw("\r\n", 2);
        }
        // Move cursor back to cl_
        int below = (int)lines_.size()-1-cl_;
        if (below>0) {
            char buf[32];
            int len = snprintf(buf, sizeof(buf), "\x1b[%dA", below);
            w_raw(buf, (size_t)len);
        }
        setCursorCol(4 + cc_);
    }

    void refreshLine() {
        w_raw("\r\x1b[2K", 5);
        w_str(cl_==0 ? "\x1b[1;32m>>> \x1b[0m" : "\x1b[1;33m... \x1b[0m");
        w_str(Highlighter::highlight(lines_[cl_]));
        setCursorCol(4 + cc_);
    }

    void insertChar(char c) {
        lines_[cl_].insert(cc_, 1, c);
        cc_++;
        refreshLine();
    }

    void doBackspace() {
        if (cc_ > 0) {
            // Smart dedent: if cursor is at indent boundary, remove 4
            bool all_sp = true;
            for (int j=0; j<cc_; j++) if (lines_[cl_][j]!=' ') { all_sp=false; break; }
            if (all_sp && cc_>0 && cc_%4==0) {
                int rm = std::min(4, cc_);
                lines_[cl_].erase(cc_-rm, rm);
                cc_ -= rm;
            } else {
                lines_[cl_].erase(--cc_, 1);
            }
            refreshLine();
        } else if (cl_ > 0) {
            int prev_len = (int)lines_[cl_-1].size();
            lines_[cl_-1] += lines_[cl_];
            lines_.erase(lines_.begin()+cl_);
            cl_--; cc_ = prev_len;
            w_raw("\x1b[J", 3); // clear below
            refreshAll();
        }
    }

    void newLine() {
        std::string rest = lines_[cl_].substr(cc_);
        lines_[cl_] = lines_[cl_].substr(0, cc_);

        std::vector<std::string> ctx(lines_.begin(), lines_.begin()+cl_+1);
        int indent = ContinuationDetector::suggestIndent(ctx);
        std::string pad(indent, ' ');

        lines_.insert(lines_.begin()+cl_+1, pad + rest);
        cl_++; cc_ = indent;
        w_raw("\r\n\x1b[J", 4);
        refreshAll();
    }

    void loadFromHistory(int idx) {
        // Clear display
        if (cl_ > 0) {
            char buf[32];
            int len = snprintf(buf, sizeof(buf), "\x1b[%dA", cl_);
            w_raw(buf, (size_t)len);
        }
        w_raw("\r\x1b[J", 4);

        if (idx >= (int)history_.size()) {
            lines_ = {""};
        } else {
            lines_.clear();
            std::string entry = history_[idx];
            size_t pos = 0;
            while (pos < entry.size()) {
                size_t nl = entry.find('\n', pos);
                if (nl == std::string::npos) { lines_.push_back(entry.substr(pos)); break; }
                lines_.push_back(entry.substr(pos, nl-pos));
                pos = nl+1;
            }
            if (lines_.empty()) lines_.push_back("");
        }
        cl_ = (int)lines_.size()-1;
        cc_ = (int)lines_[cl_].size();
        hist_idx_ = idx;
        refreshAll();
    }

public:
    enum Result { CODE, EMPTY, CANCEL, EXIT_REQ };

    Result collect(std::string& code) {
        lines_ = {""};
        cl_ = 0; cc_ = 0;
        hist_idx_ = (int)history_.size();

        term_.enableRaw();
        refreshAll();

        while (true) {
            int key = term_.readKey();
            if (key == Terminal::K_EOF) {
                term_.disableRaw();
                w_raw("\r\n", 2);
                if (lines_.size()==1 && lines_[0].empty()) return EXIT_REQ;
                break;
            }
            if (key == Terminal::K_CC) {
                term_.disableRaw();
                w_str("\x1b[0m^C\r\n");
                return CANCEL;
            }

            // ENTER: decide submit vs continue
            if (key == '\r' || key == '\n' || key == Terminal::K_ENTER) {
                // Single line: submit immediately unless it needs continuation
                if (lines_.size() == 1) {
                    if (ContinuationDetector::needsContinuation(lines_)) {
                        newLine();
                    } else {
                        w_raw("\r\n", 2);
                        break;
                    }
                    continue;
                }
                
                // Multiline mode:
                // Two consecutive empty lines -> submit
                if (lines_.size() >= 2 && ContinuationDetector::isEmpty(lines_.back()) 
                    && cl_ == (int)lines_.size()-1) {
                    // Remove trailing empty lines
                    while (lines_.size()>1 && ContinuationDetector::isEmpty(lines_.back())) lines_.pop_back();
                    w_raw("\r\n", 2);
                    break;
                }
                
                // Empty line at indent 0 when not needing continuation -> submit
                if (ContinuationDetector::isEmpty(lines_.back()) && cl_ == (int)lines_.size()-1) {
                    std::string full;
                    for (auto& l:lines_) full += l + "\n";
                    if (!ContinuationDetector::hasUnbalanced(full)) {
                        while (lines_.size()>1 && ContinuationDetector::isEmpty(lines_.back())) lines_.pop_back();
                        w_raw("\r\n", 2);
                        break;
                    }
                }
                
                // Otherwise continue with new line
                newLine();
                continue;
            }

            if (key == Terminal::K_TAB) {
                lines_[cl_].insert(cc_, "    ");
                cc_ += 4;
                refreshLine();
                continue;
            }
            if (key == Terminal::K_BS || key == Terminal::K_BS2) { doBackspace(); continue; }
            if (key == Terminal::K_DEL) {
                if (cc_ < (int)lines_[cl_].size()) {
                    lines_[cl_].erase(cc_, 1);
                    refreshLine();
                } else if (cl_ < (int)lines_.size()-1) {
                    lines_[cl_] += lines_[cl_+1];
                    lines_.erase(lines_.begin()+cl_+1);
                    w_raw("\x1b[J", 3);
                    refreshAll();
                }
                continue;
            }
            if (key == Terminal::K_LEFT || key == Terminal::K_CB) {
                if (cc_>0) { cc_--; refreshLine(); }
                else if (cl_>0) { cl_--; cc_=(int)lines_[cl_].size(); refreshAll(); }
                continue;
            }
            if (key == Terminal::K_RIGHT || key == Terminal::K_CF) {
                if (cc_<(int)lines_[cl_].size()) { cc_++; refreshLine(); }
                else if (cl_<(int)lines_.size()-1) { cl_++; cc_=0; refreshAll(); }
                continue;
            }
            if (key == Terminal::K_UP || key == Terminal::K_CP) {
                if (cl_>0) {
                    cl_--; if (cc_>(int)lines_[cl_].size()) cc_=(int)lines_[cl_].size();
                    refreshAll();
                } else if (lines_.size()==1 && hist_idx_>0) {
                    loadFromHistory(hist_idx_-1);
                }
                continue;
            }
            if (key == Terminal::K_DOWN || key == Terminal::K_CN) {
                if (cl_<(int)lines_.size()-1) {
                    cl_++; if (cc_>(int)lines_[cl_].size()) cc_=(int)lines_[cl_].size();
                    refreshAll();
                } else if (hist_idx_<(int)history_.size()) {
                    loadFromHistory(hist_idx_+1);
                }
                continue;
            }
            if (key == Terminal::K_HOME || key == Terminal::K_CA) { cc_=0; refreshLine(); continue; }
            if (key == Terminal::K_END  || key == Terminal::K_CE) { cc_=(int)lines_[cl_].size(); refreshLine(); continue; }
            if (key == Terminal::K_CL) { w_raw("\x1b[2J\x1b[H", 7); refreshAll(); continue; }
            if (key == Terminal::K_CU) { lines_[cl_].erase(0, cc_); cc_=0; refreshLine(); continue; }
            if (key == Terminal::K_CK) { lines_[cl_].erase(cc_); refreshLine(); continue; }
            if (key == Terminal::K_CW) {
                int e=cc_;
                while (cc_>0 && lines_[cl_][cc_-1]==' ') cc_--;
                while (cc_>0 && lines_[cl_][cc_-1]!=' ') cc_--;
                lines_[cl_].erase(cc_, e-cc_);
                refreshLine(); continue;
            }
            if (key == Terminal::K_CD) {
                if (lines_.size()==1 && lines_[0].empty()) {
                    term_.disableRaw();
                    w_raw("\r\n", 2);
                    return EXIT_REQ;
                }
                continue;
            }

            if (key >= 32 && key < 127) {
                insertChar((char)key);
                continue;
            }
        }

        term_.disableRaw();

        code.clear();
        bool all_empty = true;
        for (auto& l:lines_) if (l.find_first_not_of(" \t\r\n")!=std::string::npos) all_empty=false;
        if (all_empty) return EMPTY;

        for (size_t i=0; i<lines_.size(); i++) {
            if (i>0) code += "\n";
            code += lines_[i];
        }

        // Save to history
        auto p = code.find_first_not_of(" \t\r\n");
        if (p != std::string::npos && (history_.empty() || history_.back()!=code)) {
            history_.push_back(code);
            while (history_.size()>1000) history_.erase(history_.begin());
        }

        return CODE;
    }

    Terminal& terminal() { return term_; }
};

// Keep backward compat name
using MultilineCollector = MultilineEditor;

}} // namespace nython::repl_engine
