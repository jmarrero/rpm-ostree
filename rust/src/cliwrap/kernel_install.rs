// If not running on container continue the current path.
// SPDX-License-Identifier: Apache-2.0 OR MIT
use anyhow::{anyhow, Result};
use cap_std::fs::{Dir, FileType};
use cap_std_ext::cap_std;
use std::fs;
use std::process::Command;
use std::path::Path;

/// Primary entrypoint to running our wrapped `kernel-install` handling.
pub(crate) fn main() -> Result<()> {
    //finds which the kernel to remove and which to generate the initramfs for.

    let modules_path = Dir::open_ambient_dir("lib/modules", cap_std::ambient_authority())?;
    //kernel-install is called by kernel-core and kernel-modules cleanup let's make sure we just call dracut once.
    let mut new_kernel:Option<String> = None;

    for entry in modules_path.entries()?  {
        let entry = entry?;
        let fname = entry.file_name().into_string();
        let kernel_dir = fname.unwrap();
        let kernel_binary = "vmlinuz";
        let initramfs = "initramfs.img";

        if entry.file_type()? == FileType::dir() {
            print!("Testing---> {:?}\n", kernel_dir);
            if modules_path.metadata((Path::new("").join(kernel_dir.as_str())).join(kernel_binary)).is_ok(){
                print!("Testing---> YES there is a vmlinuz");
              if !modules_path.metadata((Path::new("").join(kernel_dir.as_str())).join(initramfs)).is_ok(){
                print!("Testing---> there is no initramfs\n");
                new_kernel = Some(kernel_dir);
              } else {
                print!("Testing---> But there is a initramfs not calling dracut\n");
                new_kernel = None;
              }
            } else {
                new_kernel = None;
                print!("NO vmlinuz, deleting {:?}\n", kernel_dir);
                modules_path.remove_dir_all(kernel_dir)?;
            }
        }
    }
    if new_kernel.is_some() {
        print!("Testing---> RUN DRACUT####");
        run_dracut(new_kernel.unwrap().as_str())?;
    }
    Ok(())
}

fn run_dracut(kernel_dir: &str) -> Result<()> {
        fs::create_dir("/tmp/dracut")?;
        let res = Command::new("/usr/libexec/rpm-ostree/wrapped/dracut")
            .args(&["--no-hostonly", "--kver", kernel_dir, "--reproducible", "-v", "--add", "ostree", "--tmpdir=/tmp/dracut", "-f", "/tmp/initramfs.img"])
            .status()?;
        if !res.success() {
            return Err(anyhow!("Could not generate initramfs.img successfully for kernel: {:?}", kernel_dir));
        }
        fs::rename("/tmp/initramfs.img", (Path::new("/lib/modules").join(kernel_dir)).join("initramfs.img"))?;
        Ok(())
}
