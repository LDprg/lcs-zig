const std = @import("std");
const zbench = @import("zbench");

const LCSBenchmark = struct {
    loops: usize,
    func: *const fn (std.mem.Allocator, str1: []const u8, str2: []const u8) std.mem.Allocator.Error![]const u8,
    str1: []const u8,
    str2: []const u8,


    fn init(
        loops: usize,
        func: *const fn (std.mem.Allocator, str1: []const u8, str2: []const u8) std.mem.Allocator.Error![]const u8,
        str1: []const u8,
        str2: []const u8,
    ) LCSBenchmark {
        return .{
            .loops = loops,
            .func = func,
            .str1 = str1,
            .str2 = str2,
        };
    }

    pub fn run(self: LCSBenchmark, alloc: std.mem.Allocator) void {
        for (0..self.loops) |_| {
            const data = self.func(alloc, self.str1, self.str2) catch std.debug.panic("FAILED", .{});
            std.mem.doNotOptimizeAway(data);
            alloc.free(data);
        }
    }
};

pub fn main() !void {
    const runs = 20;
    const str1 = "abcdxyz";
    const str2 = "xyzabcd";

    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const alloc = gpa.allocator();
    const stdout = std.io.getStdOut().writer();
    var bench = zbench.Benchmark.init(alloc, .{});
    defer {
        bench.deinit();
        const deinit_status = gpa.deinit();
        if (deinit_status == .leak) std.debug.panic("Memory leak detected", .{});
    }

    try bench.addParam("Reference impl.", &LCSBenchmark.init(1_000, refLCS, str1, str2), .{
        .iterations = runs,
        .track_allocations = true,
        .use_shuffling_allocator = true,
    });
    try bench.addParam("Lower memory impl.", &LCSBenchmark.init(1_000, lessSpaceLCS, str1, str2), .{
        .iterations = runs,
        .track_allocations = true,
        .use_shuffling_allocator = true,
    });

    try stdout.writeAll("\n");

    try zbench.prettyPrintHeader(stdout);
    var iter = try bench.iterator();

    const root_node = std.Progress.start(.{ .root_name = "Benchmarks running...", .estimated_total_items = iter.remaining.len });
    defer root_node.end();
    const runs_node = root_node.start("Runs", iter.remaining[0].config.iterations);
    defer runs_node.end();
    var current_node = root_node.start(iter.remaining[0].name, 0);
    defer current_node.end();

    while (try iter.next()) |step| switch (step) {
        .progress => |i| {
            current_node.end();
            current_node = root_node.start(iter.remaining[0].name, 0);
            root_node.setEstimatedTotalItems(i.total_benchmarks);
            root_node.setCompletedItems(i.completed_benchmarks);
            runs_node.setEstimatedTotalItems(i.total_runs);
            runs_node.setCompletedItems(i.completed_runs);
        },
        .result => |x| {
            defer x.deinit();
            try x.prettyPrint(alloc, stdout, true);
        },
    };
}

test "Ref LCS impl." {
    const alloc = std.testing.allocator;
    const str1 = "abcdxyz";
    const str2 = "xyzabcd";
    const sol = "abcd";

    const res = try refLCS(alloc, str1, str2);
    defer alloc.free(res);

    try std.testing.expect(std.mem.eql(u8, sol, res));
}

pub fn refLCS(alloc: std.mem.Allocator, str1: []const u8, str2: []const u8) std.mem.Allocator.Error![]const u8 {
    var table: [][]usize = try alloc.alloc([]usize, str1.len + 1);
    for (table) |*row| {
        row.* = try alloc.alloc(usize, str2.len + 1);
        for (row.*) |*elem| {
            elem.* = 0;
        }
    }
    defer {
        for (table) |*row| {
            alloc.free(row.*);
        }
        alloc.free(table);
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


test "Less Space LCS impl." {
    const alloc = std.testing.allocator;
    const str1 = "abcdxyz";
    const str2 = "xyzabcd";
    const sol = "abcd";

    const res = try lessSpaceLCS(alloc, str1, str2);
    defer alloc.free(res);

    try std.testing.expect(std.mem.eql(u8, sol, res));
}
pub fn lessSpaceLCS(alloc: std.mem.Allocator, str1: []const u8, str2: []const u8) std.mem.Allocator.Error![]const u8 {
    var table: [][]usize = try alloc.alloc([]usize, str1.len);
    for (table) |*row| {
        row.* = try alloc.alloc(usize, str2.len);
    }
    defer {
        for (table) |*row| {
            alloc.free(row.*);
        }
        alloc.free(table);
    }

    for (str1, 0..) |c1, i| {
        for (str2, 0..) |c2, j| {
            if (c1 == c2) {
                if (i > 0 and j > 0) {
                    table[i][j] = table[i - 1][j - 1] + 1;
                } else {
                    table[i][j] = 1;
                }
            } else {
                const l = if (i > 0) table[i - 1][j] else 0;
                const r = if (j > 0) table[i][j - 1] else 0;
                table[i][j] = @max(l, r);
            }
        }
    }

    var out = try alloc.alloc(u8, table[str1.len - 1][str2.len - 1]);
    var idx = out.len;

    var i = str1.len;
    var j = str2.len;

    while (i > 0 and j > 0) {
        if (str1[i - 1] == str2[j - 1]) {
            idx -= 1;
            out[idx] = str1[i - 1];
            i -= 1;
            j -= 1;
        } else if (table[i - 2][j - 1] >= table[i - 1][j - 2]) {
            i -= 1;
        } else {
            j -= 1;
        }
    }

    return out;
}
