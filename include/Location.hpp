#pragma once
#include <cstdint>
#include <string>
#include <iostream>
#include <sstream>

namespace nython::lexer {

struct Location {

    uint32_t row         = 1;
    uint32_t column      = 1;
    std::string filename = "stdin";

    Location() = default;

    Location(uint32_t r, uint32_t c, const std::string& fname)
        : row{r}, column{c}, filename{fname} {}

    explicit Location(const std::string& fname)
        : row{1}, column{1}, filename{fname} {}

    Location(const Location&) = default;
    Location(Location&&) noexcept = default;
    Location& operator=(const Location&) = default;
    Location& operator=(Location&&) noexcept = default;
    ~Location() = default;

    void reset(uint32_t new_row = 1, uint32_t /*new_column*/ = 1) {
        row    = new_row;
        column = 1;
    }

    bool operator==(const Location& other) const = default;

    bool operator<(const Location& other) const {
        if (row != other.row) return row < other.row;
        return column < other.column;
    }

    friend std::ostream& operator<<(std::ostream& os, const Location& location) {
        location.write_to_stream(os);
        return os;
    }

    void write_to_stream(std::ostream& stream) const {
        stream << "In file: " << filename << " in row(" << row << ") and column(" << column << ")";
    }

    [[nodiscard]] std::string toString() const {
        std::ostringstream os;
        write_to_stream(os);
        return os.str();
    }

    explicit operator std::string() const {
        return toString();
    }
};

}
