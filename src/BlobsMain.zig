const std = @import("std");
const sdl = @import("cImport.zig");
const Thread = std.Thread;

const VecSize = 8;
const nBlobs = 20;
const norm = 0.285;
const offs = 1;

const refreshrate = 50; //[ms]

const v8 = @Vector(8, f32);
const v16 = @Vector(16, f32);
const v8u = @Vector(8, u8);
const v16u = @Vector(16, u8);
const vType = if (VecSize == 16) v16 else v8;
const vTypeU = if (VecSize == 16) v16u else v8u;

const v8step = v8{ 0, 1, 2, 3, 4, 5, 6, 7 };
const v16step = v16{ 0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15 };
const vStep = if (VecSize == 16) v16step else v8step;

inline fn vConst(f: comptime_float) vType {
    return @as(vType, @splat(f));
}
inline fn vFromInt(n: i32) vType {
    return @as(vType, @splat(@floatFromInt(n)));
}
inline fn vFromUint(n: u32) vType {
    return @as(vType, @splat(@floatFromInt(n)));
}
inline fn vFromFloat(f: f32) vType {
    return @as(vType, @splat(f));
}

var gpa = std.heap.GeneralPurposeAllocator(.{}){};
const allocator = gpa.allocator();
var prng: std.Random.DefaultPrng = undefined;
var canvaspixels: [*]u8 = undefined;
var blobs: [nBlobs]Blob = undefined;
var VecWidth: u32 = undefined;
var width: u32 = 0;
var height: u32 = 0;

const Blob = struct {
    x: i16,
    y: i16,
    vx: i16,
    vy: i16,
    r: u32,
    width: i16,
    height: i16,
    pub fn init(w: u32, h: u32) Blob {
        return .{
            .x = prng.random().intRangeAtMost(i16, 0, @intCast(w)),
            .y = prng.random().intRangeAtMost(i16, 0, @intCast(h)),
            .vx = prng.random().intRangeAtMost(i16, -10, 10),
            .vy = prng.random().intRangeAtMost(i16, -10, 10),
            .r = 100 + prng.random().uintAtMost(u32, 100),
            .width = @intCast(w),
            .height = @intCast(h),
        };
    }
    pub fn update(self: *Blob) void {
        self.*.x += self.vx;
        self.*.y += self.vy;
        if (self.x < 0 or self.x > self.width) self.*.vx *= -1;
        if (self.y < 0 or self.y > self.height) self.*.vy *= -1;
    }
};

inline fn Kernel(x: u32, y: u32, xc: i16, yc: i16, r: u32) vType {
    const vx: vType = vStep + vFromUint(x) - vFromInt(xc);
    const vy: vType = vFromUint(y) - vFromInt(yc);
    return vFromUint(r) / @sqrt(vx * vx + vy * vy);
}

inline fn Normalise(x: vType) vType {
    return @max(@min(x * vConst(norm) - vConst(offs), vConst(1)), vConst(0));
}

fn CalculateLine(y: usize) void {
    var canvascursor: usize = y * width * 4;
    for (0..VecWidth) |x| {
        var res = vConst(0);
        for (&blobs) |blob| res += Kernel(@intCast(x * VecSize), @intCast(y), blob.x, blob.y, blob.r);
        res = Normalise(res);
        for (0..VecSize) |index| {
            canvaspixels[canvascursor + 2] = ConvU(ChannelR(res))[index];
            canvaspixels[canvascursor + 1] = ConvU(ChannelG(res))[index];
            canvaspixels[canvascursor] = ConvU(ChannelB(res))[index];
            canvascursor += 4;
        }
    }
}

fn ChannelR(v: vType) vType {
    const k = @mod((vConst(5) + vConst(6) * v), vConst(6));
    return vConst(1) - @max(vConst(0), @min(vConst(1), @min(k, vConst(4) - k)));
}
fn ChannelG(v: vType) vType {
    const k = @mod((vConst(3) + vConst(6) * v), vConst(6));
    return vConst(1) - @max(vConst(0), @min(vConst(1), @min(k, vConst(4) - k)));
}
fn ChannelB(v: vType) vType {
    const k = @mod((vConst(1) + vConst(6) * v), vConst(6));
    return vConst(1) - @max(vConst(0), @min(vConst(1), @min(k, vConst(4) - k)));
}

inline fn ConvU(v: vType) vTypeU {
    return @intFromFloat(v * vConst(255));
}

pub fn main() !void {
    // initialise Randomizer
    var seed: u64 = undefined;
    try std.posix.getrandom(std.mem.asBytes(&seed));
    prng = std.Random.DefaultPrng.init(seed);
    // initialise SDL
    if (sdl.SDL_Init(sdl.SDL_INIT_TIMER | sdl.SDL_INIT_VIDEO) != 0) {
        std.debug.print("SDL initialisation error: {s}\n", .{sdl.SDL_GetError()});
        return error.sdl_initialisationerror;
    }
    defer sdl.SDL_Quit();

    // Prepare full screen (stable alternative for linux)
    var dm: sdl.SDL_DisplayMode = undefined;
    if (sdl.SDL_GetDisplayMode(0, 0, &dm) != 0) {
        std.debug.print("SDL GetDisplayMode error: {s}\n", .{sdl.SDL_GetError()});
        return error.sdl_initialisationerror;
    }
    const window: *sdl.SDL_Window = sdl.SDL_CreateWindow(
        "Game window",
        0,
        0,
        dm.w,
        dm.h,
        sdl.SDL_WINDOW_BORDERLESS | sdl.SDL_WINDOW_MAXIMIZED,
    ) orelse {
        std.debug.print("SDL window creation failed: {s}\n", .{sdl.SDL_GetError()});
        return error.sdl_initialisationerror;
    };
    defer sdl.SDL_DestroyWindow(window);
    const canvas: *sdl.SDL_Surface = sdl.SDL_GetWindowSurface(window) orelse {
        std.debug.print("SDL window surface creation failed: {s}\n", .{sdl.SDL_GetError()});
        return error.initialisationerror;
    };
    var cpubar = sdl.SDL_Rect{ .x = 0, .y = canvas.h - 10, .w = 500, .h = 10 };
    width = @intCast(canvas.w);
    height = @intCast(canvas.h);
    std.debug.print("Window dimensions: {}x{}\n", .{ width, height });
    if (width % VecSize > 0) {
        std.debug.print("Window width ({}) not divisible by Vector Size ({})\n", .{ width, VecSize });
        return error.initialisation;
    }
    canvaspixels = @as([*]u8, @ptrCast(@alignCast(canvas.pixels)));
    VecWidth = width / VecSize;

    // initialise Pool
    var waitgroup = std.Thread.WaitGroup{};
    var pool = std.Thread.Pool{
        .allocator = allocator,
        .threads = &[_]Thread{},
    };
    try pool.init(.{ .allocator = allocator });
    defer pool.deinit();

    // Tweak background openGL to avoid screen flickering
    if (sdl.SDL_GL_GetCurrentContext() != null) {
        _ = sdl.SDL_GL_SetSwapInterval(1);
        std.debug.print("Adapted current openGL context for vSync\n", .{});
    }

    // Hide mouse
    _ = sdl.SDL_ShowCursor(sdl.SDL_DISABLE);

    for (&blobs) |*blob| blob.* = Blob.init(width, height);

    var timer = try std.time.Timer.start();
    var stoploop = false;
    var event: sdl.SDL_Event = undefined;
    while (!stoploop) {
        timer.reset();
        _ = sdl.SDL_UpdateWindowSurface(window);
        waitgroup.reset();
        for (0..height) |y| pool.spawnWg(&waitgroup, CalculateLine, .{y});
        pool.waitAndWork(&waitgroup);
        for (&blobs) |*blob| blob.*.update();
        while (sdl.SDL_PollEvent(&event) != 0) {
            if (event.type == sdl.SDL_KEYDOWN) stoploop = true;
        }
        const tStop = timer.read() / 1_000_000;
        const lap: u32 = @intCast(tStop);
        cpubar.w = @intCast(@min(width, tStop * width / refreshrate));

        _ = sdl.SDL_FillRect(canvas, &cpubar, 0xffffffff);
        if (lap < refreshrate) sdl.SDL_Delay(refreshrate - lap);
    }
    std.debug.print("All done.\n", .{});
}
