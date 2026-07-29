fn main() {
    #[cfg(target_arch = "aarch64")]
    let architecture = "AArch64";

    #[cfg(target_arch = "arm")]
    let architecture = "ARMv7";

    println!(
        "language=Rust arch={} pointer_bits={} usize_max={}",
        architecture,
        usize::BITS,
        usize::MAX
    );
}
