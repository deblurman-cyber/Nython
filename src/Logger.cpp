// Author: Darshan Sen (RaisinTen)

#include "Logger.hpp"
#include "Definitions.hpp"

#include <map>

namespace nython::kernel
{
    using std::vector;
    using std::string;
    using std::ostream;
    using std::map;
    using std::endl;

    const static string NOC{"\033[0m"};
    const static string RED{"\033[1;31;40m"};
    const static string YEL{"\033[1;33;40m"};
    const static string BLU{"\033[1;36;40m"};
    const static string LOC{"\033[1;30;47m"};
    const static string MSG{"\033[1;3;37;40m"};
    const static string IND{"\033[1;32;40m"};

    const static map<LogType, string> log_type_to_string
    {
        {LogType::error,    " " + RED + "ERROR:"    + NOC + " "},
        {LogType::warning,  " " + YEL + "WARNING:"  + NOC + " "},
        {LogType::note,     " " + BLU + "NOTE:"     + NOC + " "},
    };

    /*** class Log ***/

    Log::Log(const LogType log_type, const string& message, const size_t line, const size_t column): m_log_type{log_type}, m_message{message}, m_line{line}, m_column{column} {
    }

    ostream& operator<<(ostream& stream, const Log& log) {
        stream << LOC << io::file_name << ":";

        if(log.m_line)
        {
            stream << log.m_line << ":";

            if(log.m_column)
            {
                stream << log.m_column << ":";
            }
        }

        stream << NOC;

        stream << log_type_to_string.at(log.m_log_type) << MSG << log.m_message << NOC ;

        if(log.m_line)
        {
            const auto line{io::lines[log.m_line - 1]};

            stream << "\n\t" << NOC << line;

            if(log.m_column)
            {
                stream << "\n\t";

                // moving the cursor to the appropriate location
                for(size_t i = 0; i < log.m_column - 1; ++i)
                {
                    if(line[i] == '\t')
                    {
                        stream << "\t";
                    }
                    else
                    {
                        stream << " ";
                    }
                }

                stream << IND << "^" << NOC;
            }
        }

        stream << "\n";

        return stream;
    }

    /*** class Logger ***/

    bool Logger::empty() const
    {
        return m_logs.empty();
    }

    const Log& Logger::operator[](const int index) const
    {
        if(index >= 0)
        {
            return m_logs[index];
        }
        else
        {
            return m_logs[static_cast<int>(m_logs.size()) + index];
        }
    }

    void Logger::add(const Log& log)
    {
        m_logs.emplace_back(log);
    }

    void Logger::add(const LogType log_type, const string& message, const size_t line, const size_t column)
    {
        m_logs.emplace_back(
            Log {
                log_type,
                message,
                line,
                column
            }
        );
    }

    Logger& Logger::operator<<(const Log& log)
    {
        m_logs.emplace_back(log);

        return *(this);
    }

    void Logger::clear()
    {
        m_logs.clear();
    }

    ostream& operator<<(ostream& stream, const Logger& logger)
    {
        for(const auto& log : logger.m_logs)
        {
            stream << log ;
        }

        return stream;
    }
}

