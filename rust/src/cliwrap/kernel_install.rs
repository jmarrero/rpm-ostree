// If not running on container continue the current path.
// SPDX-License-Identifier: Apache-2.0 OR MIT
use anyhow::{anyhow, Result};
use std::fs;
use std::process::Command;


/// Primary entrypoint to running our wrapped `kernel-install` handling.
pub(crate) fn main() -> Result<()> {
    remove_current_kernel()?;
    run_dracut()?;
    Ok(())
}

fn remove_current_kernel() -> Result<()> {
    let modules_dir = "/lib/modules";
    let kernel_bin = "vmlinuz";
    let paths = fs::read_dir(modules_dir).unwrap();

    for path in paths {
        let current_path = path.unwrap().path();
        let file_path = current_path.join(kernel_bin);
        if !fs::metadata(file_path).is_ok() {
            fs::remove_dir_all(current_path)?;
        }
    }
    Ok(())
}

fn run_dracut() -> Result<()> {
    fs::create_dir("/tmp/dracut")?;
    let res = Command::new("/usr/libexec/rpm-ostree/wrapped/dracut")
        .args(&["--no-hostonly", "--kver", "5.17.11-300.fc36.x86_64", "--reproducible", "-v", "--add", "ostree", "--tmpdir=/tmp/dracut", "-f", "/tmp/initramfs.img"])
        .status()?;
    if !res.success() {
        return Err(anyhow!("#sad"));
    }
    fs::rename("/tmp/initramfs.img", "/lib/modules/5.17.11-300.fc36.x86_64/initramfs.img")?;
    Ok(())
}
