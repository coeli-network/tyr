const vm_cell = struct {
    atom: *u32,
    child: *vm_cell,

};

const vm_state = struct {
    mem: [256]vm_cell,
    subject: vm_cell
};
