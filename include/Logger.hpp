// Author: Darshan Sen (RaisinTen)

#pragma once

#include <ostream>
#include <vector>
#include <string>

namespace nython::kernel
{
    using std::vector;
    using std::string;
    using std::ostream;

    enum class LogType
    {
        error,
        warning,
        note,
    };

    class Log
    {
        LogType m_log_type;
        string m_message;
        size_t m_line;
        size_t m_column;
    public:
        Log(const LogType log_type, const string& message, const size_t line = 0u, const size_t column = 0u);
        friend ostream& operator<<(ostream& stream, const Log& log);
    };

    class Logger
    {
        vector<Log> m_logs;
    public:
        Logger(): m_logs{} {}
        ~Logger() {}
        bool empty() const;
        const Log& operator[](const int index) const;
        void add(const Log& log);
        void add(const LogType log_type, const string& message, const size_t line = 0u, const size_t column = 0u);
        Logger& operator<<(const Log& log);
        void clear();
        friend ostream& operator<<(ostream& stream, const Logger& logger);
    };
}

