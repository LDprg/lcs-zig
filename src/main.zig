const std = @import("std");

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const alloc = gpa.allocator();

    const str1 = "abcdxyz";
    const str2 = "xyzabcd";

    const res = try refLCS(alloc, str1, str2);

    std.debug.print("Str1: \"{s}\"\nStr2: \"{s}\"\nRes: \"{s}\"\n", .{ str1, str2, res });
}

pub fn refLCS(alloc: std.mem.Allocator, str1: []const u8, str2: []const u8) ![]const u8 {
    var table: [][]usize = try alloc.alloc([]usize, str1.len + 1);
    for (table) |*row| {
        row.* = try alloc.alloc(usize, str2.len + 1);
        for (row.*) |*elem| {
            elem.* = 0;
        }
    }

    for (str1, 0..) |c1, i| {
        for (str2, 0..) |c2, j| {
            if (c1 == c2) {
                table[i + 1][j + 1] = table[i][j] + 1;
            } else {
                table[i + 1][j + 1] = @max(table[i][j + 1], table[i + 1][j]);
            }
        }
    }

    var i = str1.len;
    var j = str2.len;

    var out = try alloc.alloc(u8, table[i][j]);
    var idx = table[i][j];

    while (i > 0 and j > 0) {
        if (str1[i - 1] == str2[j - 1]) {
            idx -= 1;
            out[idx] = str1[i - 1];
            i -= 1;
            j -= 1;
        } else if (table[i - 1][j] >= table[i][j - 1]) {
            i -= 1;
        } else {
            j -= 1;
        }
    }

    return out;
}
