// Test-only SourceMod string bindings for AlliedModders' SourcePawn shell.
// Conversion algorithms remain in the actual include compiled into the SMX.
#include <algorithm>
#include <cctype>
#include <cstdint>
#include <cstring>
#include <string>

static const char* OfflineRead(IPluginContext* cx, cell_t address) {
  char* result = nullptr;
  if (int error = cx->LocalToString(address, &result)) {
    cx->ThrowNativeErrorEx(error, "Invalid test string address");
    return "";
  }
  return result;
}

static cell_t OfflineWrite(IPluginContext* cx, cell_t address, cell_t capacity,
                           const std::string& value) {
  if (capacity <= 0)
    return 0;
  if (int error = cx->StringToLocal(address, size_t(capacity), value.c_str()))
    return cx->ThrowNativeErrorEx(error, "Invalid test output address");
  return cell_t(std::min(value.size(), size_t(capacity - 1)));
}

static std::string OfflineCase(std::string value, bool sensitive) {
  if (!sensitive) {
    for (char& character : value)
      character = char(std::tolower(static_cast<unsigned char>(character)));
  }
  return value;
}

static cell_t OfflineLength(IPluginContext* cx, const cell_t* p) {
  return cell_t(std::strlen(OfflineRead(cx, p[1])));
}

static cell_t OfflineNumeric(IPluginContext*, const cell_t* p) {
  return p[1] >= '0' && p[1] <= '9';
}

static cell_t OfflineCompare(IPluginContext* cx, const cell_t* p) {
  auto left = OfflineCase(OfflineRead(cx, p[1]), p[3] != 0);
  auto right = OfflineCase(OfflineRead(cx, p[2]), p[3] != 0);
  return left < right ? -1 : left > right ? 1 : 0;
}

static cell_t OfflineContains(IPluginContext* cx, const cell_t* p) {
  auto source = OfflineCase(OfflineRead(cx, p[1]), p[3] != 0);
  auto part = OfflineCase(OfflineRead(cx, p[2]), p[3] != 0);
  auto position = source.find(part);
  return position == std::string::npos ? -1 : cell_t(position);
}

static cell_t OfflineCopy(IPluginContext* cx, const cell_t* p) {
  return OfflineWrite(cx, p[1], p[2], OfflineRead(cx, p[3]));
}

static cell_t OfflineSplit(IPluginContext* cx, const cell_t* p) {
  std::string source = OfflineRead(cx, p[1]);
  std::string delimiter = OfflineRead(cx, p[2]);
  auto position = source.find(delimiter);
  if (delimiter.empty() || position == std::string::npos)
    return -1;
  OfflineWrite(cx, p[3], p[4], source.substr(0, position));
  return cell_t(position + delimiter.size());
}

static cell_t OfflineParse(IPluginContext* cx, const cell_t* p) {
  // SourceMod uses strtoul. Model its 32-bit Linux unsigned-long limit even
  // though this test shell is x86_64. Overflow saturates before the cell cast.
  const char* input = OfflineRead(cx, p[1]);
  while (std::isspace(static_cast<unsigned char>(*input)))
    input++;
  bool negative = *input == '-';
  if (*input == '-' || *input == '+')
    input++;
  auto magnitude = std::strtoull(input, nullptr, p[2]);
  if (magnitude > UINT32_MAX)
    return cell_t(UINT32_MAX);
  return cell_t(negative ? uint32_t(0) - uint32_t(magnitude) : uint32_t(magnitude));
}

static cell_t OfflineInt(IPluginContext* cx, const cell_t* p) {
  return OfflineWrite(cx, p[2], p[3], std::to_string(p[1]));
}

static cell_t OfflineFormat(IPluginContext* cx, const cell_t* p) {
  std::string format = OfflineRead(cx, p[3]);
  std::string result;
  size_t argument = 4;
  for (size_t i = 0; i < format.size(); i++) {
    if (format[i] != '%') {
      result += format[i];
      continue;
    }
    if (++i == format.size())
      return cx->ThrowNativeError("Incomplete test format");
    char specifier = format[i];
    if (specifier == '%') {
      result += '%';
      continue;
    }
    if (argument > size_t(p[0]))
      return cx->ThrowNativeError("Missing test format argument");
    if (specifier == 's') {
      result += OfflineRead(cx, p[argument++]);
      continue;
    }
    cell_t* value = nullptr;
    if (int error = cx->LocalToPhysAddr(p[argument++], &value))
      return cx->ThrowNativeErrorEx(error, "Invalid test format argument");
    if (specifier == 'd' || specifier == 'i')
      result += std::to_string(*value);
    else if (specifier == 'u')
      result += std::to_string(uint32_t(*value));
    else
      return cx->ThrowNativeError("Unsupported test format specifier");
  }
  return OfflineWrite(cx, p[1], p[2], result);
}

static void BindOfflineStringNatives(IPluginRuntime* rt) {
  BindNative(rt, "strlen", OfflineLength);
  BindNative(rt, "IsCharNumeric", OfflineNumeric);
  BindNative(rt, "strcmp", OfflineCompare);
  BindNative(rt, "StrContains", OfflineContains);
  BindNative(rt, "strcopy", OfflineCopy);
  BindNative(rt, "SplitString", OfflineSplit);
  BindNative(rt, "StringToInt", OfflineParse);
  BindNative(rt, "IntToString", OfflineInt);
  BindNative(rt, "Format", OfflineFormat);
}
