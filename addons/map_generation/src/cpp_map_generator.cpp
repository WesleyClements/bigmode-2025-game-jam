#include "cpp_map_generator.h"
#include <godot_cpp/core/class_db.hpp>

using namespace godot;

void
CppMapGenerator::_bind_methods()
{
  ClassDB::bind_static_method(
    "CppMapGenerator",
    D_METHOD(
      "smooth",
      "input_map",
      "width",
      "height",
      "steps",
      "death_limit",
      "birth_limit"
    ),
    &CppMapGenerator::smooth
  );
  ClassDB::bind_static_method(
    "CppMapGenerator",
    D_METHOD(
      "count_neighbors", "input_map", "width", "height", "x", "y", "radius"
    ),
    &CppMapGenerator::count_neighbors
  );
}

CppMapGenerator::CppMapGenerator()
{
  // Initialize any variables here.
}

CppMapGenerator::~CppMapGenerator()
{
  // Add your cleanup here.
}

TypedArray<int32_t>
CppMapGenerator::smooth(
  TypedArray<int32_t> input_map,
  int32_t width,
  int32_t height,
  int32_t steps,
  int32_t death_limit,
  int32_t birth_limit
)
{
  TypedArray<int32_t> input = TypedArray<int32_t>(input_map);
  TypedArray<int32_t> temp = TypedArray<int32_t>();
  temp.resize(width * height);

  for (int32_t i = 0; i < steps; i++) {
    for (int32_t y = 0; y < height; y++) {
      int32_t row_offset = y * width;
      for (int32_t x = 0; x < width; x++) {
        int32_t index = row_offset + x;
        int32_t current_value = input[index];
        int32_t neighbor_count = count_neighbors(input, width, height, x, y);

        if (current_value != 0) {
          if (neighbor_count < death_limit) {
            temp[index] = 0;
          }
          else {
            temp[index] = current_value;
          }
        }
        else {
          if (neighbor_count > birth_limit) {
            temp[index] = 1;
          }
          else {
            temp[index] = 0;
          }
        }
      }
    }
    TypedArray<int32_t> swap = input;
    input = temp;
    temp = swap;
  }
  return temp;
}

int32_t
CppMapGenerator::count_neighbors(
  TypedArray<int32_t> input_map,
  int32_t width,
  int32_t height,
  int32_t x,
  int32_t y,
  int32_t radius
)
{
  int32_t count = 0;
  for (int32_t offset_y = -radius; offset_y <= radius; offset_y++) {
    int32_t neighbor_y = y + offset_y;
    if (neighbor_y < 0 || neighbor_y >= height) {
      count += 3;
      continue;
    }
    for (int32_t offset_x = -radius; offset_x <= radius; offset_x++) {
      int32_t neighbor_x = x + offset_x;
      if (offset_x == 0 && offset_y == 0) {
        continue;
      }
      if (neighbor_x < 0 || neighbor_x >= width) {
        count++;
        continue;
      }
      else {
        int32_t value = input_map[neighbor_y * width + neighbor_x];
        if (value != 0) {
          count++;
        }
      }
    }
  }
  return count;
}