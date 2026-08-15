#include <string>
#include <vector>
#include <cstdint>
#include <cstring>

#pragma once


namespace nython {

namespace kernel {
class String;
}

namespace reader {

class MemoryBlock {

    friend class nython::kernel::String;

    static constexpr const size_t kInitialCapacity = 64;
    static constexpr const float kGrowthFactor     = 2;

protected:

    uint8_t* data;
    size_t capacity    = kInitialCapacity;
    size_t writeoffset = 0;

public:

    MemoryBlock() : data{nullptr} {
        this->data        = reinterpret_cast<uint8_t*>(std::malloc(kInitialCapacity));
        this->capacity    = kInitialCapacity;
        this->writeoffset = 0;
    }

    ~MemoryBlock() {
        if (this->data) {
            std::free(this->data);
            this->data = nullptr;
        }
    }

    MemoryBlock(const MemoryBlock& other) : data(nullptr) {
        this->data = reinterpret_cast<uint8_t*>(std::malloc(other.capacity));
        std::memcpy(this->data, other.data, other.capacity);
        this->capacity    = other.capacity;
        this->writeoffset = other.writeoffset;
    }

    MemoryBlock(MemoryBlock&& other) : data(nullptr) {
        this->data        = other.data;
        this->capacity    = other.capacity;
        this->writeoffset = other.writeoffset;
        std::free(other.data);
        other.data        = nullptr;
        other.capacity    = 0;
        other.writeoffset = 0;
    }

    MemoryBlock& operator=(const MemoryBlock& other) {
        if (this != &other) {
            if (this->data) {
                std::free(this->data);
            }
            this->data = reinterpret_cast<uint8_t*>(std::malloc(other.capacity));
            std::memcpy(this->data, other.data, other.capacity);
            this->capacity    = other.capacity;
            this->writeoffset = other.writeoffset;
        }
        return *this;
    }

    MemoryBlock& operator=(MemoryBlock&& other) {
        if (this != &other) {
            if (this->data) {
                std::free(this->data);
            }
            this->data        = other.data;
            this->capacity    = other.capacity;
            this->writeoffset = other.writeoffset;
            std::free(other.data);
            other.data        = nullptr;
            other.capacity    = 0;
            other.writeoffset = 0;
        }
        return *this;
    }

    // Grows the internal buffer to hold an amount of data
    inline void grow_to_fit(size_t size) {
        if (this->capacity < size) {
            // Calculate the new size
            size_t new_size = this->capacity;
            while (new_size < size) {
                new_size *= kGrowthFactor;
            }
            // Realloc the data to fit the new size
            this->data     = reinterpret_cast<uint8_t*>(std::realloc(this->data, new_size));
            this->data[new_size - 1] = L'\0';
            this->capacity = new_size;
        }
    }

    // Append data to the end of the internal buffer
    // Automatically grows the buffer to fit
    template <typename T>
    inline uint32_t write(const T& value) {
        this->grow_to_fit(this->writeoffset + sizeof(T));
        *reinterpret_cast<T*>(this->data + this->writeoffset) = value;
        this->writeoffset += sizeof(T);
        return sizeof(T);
    }

    // Shorthand methods for some commonly used types
    inline uint32_t write_u8(uint8_t val) {
        return this->write(val);
    }

    inline uint32_t write_u16(uint16_t val) {
        return this->write(val);
    }

    inline uint32_t write_u32(uint32_t val) {
        return this->write(val);
    }

    inline uint32_t write_u64(uint64_t val) {
        return this->write(val);
    }

    inline uint32_t write_double(float val) {
        return this->write(val);
    }

    inline uint32_t write_double(double val) {
        return this->write(val);
    }

    inline uint32_t write_ptr(uintptr_t val) {
        return this->write(val);
    }

    // Write data to a given offset of the internal buffer
    // Automatically grows the buffer to fit
    template <typename T>
    inline uint32_t write(const T& value, uint32_t offset) {
        this->grow_to_fit(offset + sizeof(T));
        *reinterpret_cast<T*>(this->data + offset) = value;
        return sizeof(T);
    }

    // Write a block of memory into the internal buffer
    inline size_t write_block(uint8_t* data, size_t size) {
        this->grow_to_fit(this->writeoffset + size);
        memcpy(this->data + this->writeoffset, data, size);
        this->writeoffset += size;
        return size;
    }

    // Write a block of memory into the internal buffer
    inline size_t write_block(char* data, size_t size) {
        return this->write_block(reinterpret_cast<uint8_t*>(data), size);
    }

    // Write a string into the internal buffer
    inline size_t write_string(const std::string& data) {
        this->grow_to_fit(this->writeoffset + data.size());
        memcpy(this->data + this->writeoffset, data.data(), data.size());
        this->writeoffset += data.size();
        this->data[this->writeoffset - 1] = L'\0';
        return data.size();
    }

    // Read data from a given offset
    template <typename T>
    inline T& read(size_t offset) {
        return *reinterpret_cast<T*>(this->data + offset);
    }

    // Returns a pointer to the first byte of the internal buffer
    inline uint8_t* get_data() {
        return this->data;
    }

    // Returns a pointer to the first byte of the internal buffer
    inline const char* get_const_data() {
        return reinterpret_cast<char*>(this->data);
    }

    // Returns the capacity of this memory block
    inline size_t get_capacity() {
        return this->capacity;
    }

    // Returns the current write offset into the internal buffer
    inline size_t get_writeoffset() {
        return this->writeoffset;
    }

    inline size_t get_length() {
        return this->writeoffset;
    }

    inline void clear() {
        std::memset(this->data, 0, this->capacity);
        this->writeoffset = 0;
    }

    inline std::string str() {
        return std::string(reinterpret_cast<char*>(this->data));
    }

};
}  // namespace reader
} // namesapce nython
