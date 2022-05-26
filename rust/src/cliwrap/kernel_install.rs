// Intercept /usr/bin/kernel-install

// Check if we are in a container && ostree system
// If that is the case.
    //-> use the functions from: src/libpriv/rpmostree-kernel.cxx To remove the current kernel
        //For this will need to expose these functions to rust.
    // -> Reimplement the dracut calls in rust 
        // This new code must move the new initramfs to /lib/modules/new-kernel-dir

// If not running on container continue the current path.
// SPDX-License-Identifier: Apache-2.0 OR MIT

use anyhow::{anyhow, Result};
use crate::ffi::SystemHostType;


/// Primary entrypoint to running our wrapped `kernel-install` handling.
pub(crate) fn main(hosttype: SystemHostType, argv: &[&str]) -> Result<()> {
        Ok(())
}
