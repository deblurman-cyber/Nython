
#include <string>
#include <cstring>
#include <iostream>
// utf8 provided by Definitions.hpp
#include "Definitions.hpp"
#include "MemoryBlock.hpp"

#pragma once

namespace nython::reader {

// Handles UTF8 encoded text
class Utf8Buffer extends MemoryBlock {

    size_t readoffset = 0;
    size_t lastoffset = 0;

public:

    Utf8Buffer() : MemoryBlock() {
    }

    Utf8Buffer(const Utf8Buffer& other) : MemoryBlock(), readoffset(other.readoffset) {
    }

    Utf8Buffer(Utf8Buffer&& other) : MemoryBlock(), readoffset(other.readoffset) {
    }

    Utf8Buffer& operator=(const Utf8Buffer& other) {
        this->readoffset = other.readoffset;
        this->lastoffset = other.lastoffset;
        MemoryBlock::operator=(other);
        return *this;
    }

    Utf8Buffer& operator=(Utf8Buffer&& other) {
        this->readoffset = other.readoffset;
        this->lastoffset = other.lastoffset;
        MemoryBlock::operator=(std::move(other));
        return *this;
    }

    // Load raw data into the buffer
    inline void write(const Utf8Buffer& data) {
        this->grow_to_fit(this->writeoffset + data.writeoffset);
        this->write_block(data.data, data.writeoffset);
    }

    // UTF8 methods
    uint32_t append_utf8(uint32_t cp);
    uint32_t next_utf8();
    uint32_t put_utf8(uint32_t c);
    uint32_t peek_next_utf8(size_t offset = 0);

    static inline bool is_valid_utf8(char* start, char* end) {
        return utf8::is_valid(start, end);
    }

    size_t codepointcount();
    size_t utf8_byteoffset(uint32_t start);

    static inline void write_cp_to_stream(uint32_t cp, std::ostream& stream) {
        char buffer[] = {0, 0, 0, 0};
        char* buffer_start = buffer;
        buffer_start = utf8::append(cp, buffer_start);
        stream.write(buffer, buffer_start - buffer);
    }

    static inline void write_cp_to_string(uint32_t cp, std::string& str) {
        char buffer[] = {0, 0, 0, 0};
        char* buffer_start = buffer;
        buffer_start = utf8::append(cp, buffer_start);
        str.append(buffer, buffer_start - buffer);
    }
};
}  // namespace reader

