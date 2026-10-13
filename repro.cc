// repro.cc — trip libelfin's value::as_string on a zero-length DWARF string
// attribute.
//
// value::as_string(string &buf) does:
//
//     buf.resize(size);
//     memmove(&buf.front(), p, size);
//
// with no `size > 0` guard, unlike cursor::string in dwarf/cursor.cc. When an
// attribute's string value has length 0, buf stays empty and buf.front() is
// called on an empty std::string, which aborts under _GLIBCXX_ASSERTIONS:
//
//     basic_string.h:1428: ... front() ... Assertion '!empty()' failed.
//
// This walks every DIE of every compilation unit, calling as_string on each
// attribute (ignoring the ones that are not strings).
//
// Build with -D_GLIBCXX_ASSERTIONS so the undefined behaviour becomes a hard
// abort rather than silently copying zero bytes.

#include "dwarf++.hh"
#include "elf++.hh"

#include <cstdio>
#include <cstring>
#include <fcntl.h>
#include <string>

static unsigned long string_attrs = 0;
static unsigned long empty_string_attrs = 0;

static void walk(const dwarf::die &node)
{
    for (auto &attr : node.attributes()) {
        std::string buf;
        try {
            attr.second.as_string(buf);
        } catch (...) {
            continue;               // not a string-valued attribute
        }
        string_attrs++;
        if (buf.empty()) {
            empty_string_attrs++;
            std::fprintf(stderr, "zero-length string attribute (tag %s)\n",
                         to_string(node.tag).c_str());
        }
    }

    for (auto &child : node)
        walk(child);
}

int main(int argc, char **argv)
{
    if (argc != 2) {
        std::fprintf(stderr, "usage: %s ELF-file\n", argv[0]);
        return 2;
    }

    int fd = open(argv[1], O_RDONLY);
    if (fd < 0) {
        std::perror(argv[1]);
        return 1;
    }

    elf::elf ef(elf::create_mmap_loader(fd));
    dwarf::dwarf dw(dwarf::elf::create_loader(ef));

    for (auto cu : dw.compilation_units())
        walk(cu.root());

    std::printf("walked %lu string attributes, %lu of them zero-length\n",
                string_attrs, empty_string_attrs);
    return 0;
}