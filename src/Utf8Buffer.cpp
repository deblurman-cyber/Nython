#pragma GCC diagnostic push
#pragma GCC diagnostic ignored "-Wshadow"
#include "Utf8Buffer.hpp"

namespace nython::reader {

// Append a utf8 codepoint
uint32_t Utf8Buffer::append_utf8(uint32_t cp) {
    this->grow_to_fit(this->writeoffset + 4);
    uint8_t* initial_write_pointer = this->data + this->writeoffset;
    uint8_t* write_pointer = this->data + this->writeoffset;
    write_pointer = utf8::append(cp, write_pointer);
    this->writeoffset += write_pointer - initial_write_pointer;
    return cp;
}

// Return the next utf8 codepoint
uint32_t Utf8Buffer::next_utf8() {
    if (this->readoffset >= this->writeoffset) {
        return L'\0';
    }
    uint8_t* initial_readpointer = this->data + this->readoffset;
    uint8_t* readpointer = this->data + this->readoffset;
    uint32_t cp = utf8::next(readpointer, this->data + this->writeoffset);
    this->lastoffset = this->readoffset;
    this->readoffset += readpointer - initial_readpointer;
    return cp;
}

// Return the next utf8 codepoint
uint32_t Utf8Buffer::put_utf8(uint32_t cp) {
    this->readoffset = this->lastoffset;
    return cp;
}

// Peek the next utf8 codepoint
uint32_t Utf8Buffer::peek_next_utf8(size_t offset) {
    if (this->readoffset + offset >= this->writeoffset) {
        return L'\0';
    }
    uint8_t* initial_readpointer = this->data + this->readoffset + offset;
    uint8_t* readpointer = this->data + this->readoffset + offset;
    uint32_t cp = utf8::peek_next(readpointer, this->data + this->writeoffset);
    this->readoffset += readpointer - initial_readpointer;
    return cp;
}

// Return the amount of codepoints inside the buffer
size_t Utf8Buffer::codepointcount() {
    uint8_t* data_end = this->data + this->writeoffset;
    return utf8::distance(this->data, data_end);
}

size_t Utf8Buffer::utf8_byteoffset(uint32_t start) {
    uint8_t* start_iterator = this->data;

    while (start--) {
        if (start_iterator >= this->data + this->writeoffset) {
            return this->writeoffset;
        }
        utf8::advance(start_iterator, 1, this->data + this->writeoffset);
    }
    return start_iterator - this->data;
}
}


#pragma GCC diagnostic pop
