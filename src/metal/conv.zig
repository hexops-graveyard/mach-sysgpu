const gpu = @import("gpu");
const mtl = @import("objc/mtl.zig");

pub fn metalLoadAction(op: gpu.LoadOp) mtl.LoadAction {
    return switch (op) {
        .load => mtl.LoadActionLoad,
        .clear => mtl.LoadActionClear,
        .undefined => unreachable,
    };
}

pub fn metalStoreAction(op: gpu.StoreOp) mtl.StoreAction {
    return switch (op) {
        .store => mtl.StoreActionStore,
        .discard => mtl.StoreActionDontCare,
        .undefined => unreachable,
    };
}
