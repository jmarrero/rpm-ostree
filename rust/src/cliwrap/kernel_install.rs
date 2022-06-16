// If not running on container continue the current path.
// SPDX-License-Identifier: Apache-2.0 OR MIT
use anyhow::{anyhow, Result};
use camino::Utf8Path;
use cap_std::fs::{Dir, FileType};
use cap_std::fs_utf8::Dir as Utf8Dir;
use cap_std_ext::cap_std;
use std::fs;
use std::path::Path;
use std::process::Command;

/// Primary entrypoint to running our wrapped `kernel-install` handling.
pub(crate) fn main() -> Result<()> {
    //finds which the kernel to remove and which to generate the initramfs for.

    let modules_path = Utf8Dir::open_ambient_dir("lib/modules", cap_std::ambient_authority())?;
    //kernel-install is called by kernel-core and kernel-modules cleanup let's make sure we just call dracut once.
    let mut new_kernel: Option<_> = None;

    for entry in modules_path.entries()? {
        let entry = entry?;
        let kernel_dir = entry.file_name()?;
        let kernel_path = Utf8Path::new(&kernel_dir);
        let kernel_binary = "vmlinuz";
        let initramfs = "initramfs.img";

        if entry.file_type()? == FileType::dir() {
            if modules_path.exists((kernel_path).join(kernel_binary))
            {
                if !modules_path.exists(kernel_path.join(initramfs)) {
                    new_kernel = Some(kernel_dir);
                } else {
                    new_kernel = None;
                }
            } else {
                new_kernel = None;
                modules_path.remove_dir_all(kernel_dir)?;
            }
        }
    }
    if let Some(k) = new_kernel {
        run_dracut(&k)?;
    }
    Ok(())
}

fn run_dracut(kernel_dir: &str) -> Result<()> {
    fs::create_dir("/tmp/dracut")?;
    let res = Command::new("/usr/libexec/rpm-ostree/wrapped/dracut")
        .args(&[
            "--no-hostonly",
            "--kver",
            kernel_dir,
            "--reproducible",
            "-v",
            "--add",
            "ostree",
            "--tmpdir=/tmp/dracut",
            "-f",
            "/tmp/initramfs.img",
        ])
        .status()?;
    if !res.success() {
        return Err(anyhow!(
            "Could not generate initramfs.img successfully for kernel: {:?}",
            kernel_dir
        ));
    }
    fs::rename(
        "/tmp/initramfs.img",
        (Path::new("/lib/modules").join(kernel_dir)).join("initramfs.img"),
    )?;
    Ok(())
}
