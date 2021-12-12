# SPDX-License-Identifier: EUPL-1.2
# SPDX-FileCopyrightText: 2021 Alyssa Ross <hi@alyssa.is>

{ pkgs ? import <nixpkgs> {}
, terminfo ? pkgs.foot.terminfo
}:

pkgs.pkgsStatic.callPackage (

{ lib, stdenv, runCommand, writeReferencesToFile, buildPackages
, s6-rc, tar2ext4, xorg
, busybox, connmanMinimal, dbus, execline, linux, mdevd, nftables, s6
, s6-linux-utils, s6-portable-utils
}:

let
  inherit (lib) cleanSource cleanSourceWith concatMapStringsSep;

  connman = connmanMinimal;

  packages = [
    busybox connman dbus execline mdevd s6 s6-linux-utils
    s6-portable-utils s6-rc

    (nftables.override { withCli = false; })
  ];

  packagesSysroot = runCommand "packages-sysroot" {
    inherit packages;
    nativeBuildInputs = [ xorg.lndir ];
    passAsFile = [ "packages" ];
  } ''
    mkdir -p $out/usr/bin $out/usr/share/dbus-1
    ln -s ${concatMapStringsSep " " (p: "${p}/bin/*") packages} $out/usr/bin
    ln -s ${kernel}/lib "$out"
    ln -s ${terminfo}/share/terminfo $out/usr/share

    for pkg in ${dbus} ${connman}; do
        lndir -silent $pkg/share/dbus-1 $out/usr/share/dbus-1
    done
  '';

  packagesTar = runCommand "packages.tar" {} ''
    cd ${packagesSysroot}
    tar -cf $out --verbatim-files-from \
        -T ${writeReferencesToFile packagesSysroot} .
  '';

  kernel = buildPackages.linux.override {
    structuredExtraConfig = with lib.kernel; {
      VIRTIO = yes;
      VIRTIO_PCI = yes;
      VIRTIO_BLK = yes;
      VIRTIO_CONSOLE = yes;
      EXT4_FS = yes;
      DRM_BOCHS = yes;
      DRM = yes;
      AGP = yes;
    };
  };
in

stdenv.mkDerivation {
  name = "spectrum-netvm";

  src = cleanSourceWith {
    filter = name: _type: name != "${toString ./.}/build";
    src = cleanSource ./.;
  };

  nativeBuildInputs = [ s6-rc tar2ext4 ];

  PACKAGES_TAR = packagesTar;
  VMLINUX = "${kernel.dev}/vmlinux";

  postPatch = ''
    mkdir $NIX_BUILD_TOP/empty
    substituteInPlace Makefile --replace /var/empty $NIX_BUILD_TOP/empty
  '';

  installPhase = ''
    mv build/svc $out
  '';

  enableParallelBuilding = true;

  passthru = { inherit kernel; };

  meta = with lib; {
    license = licenses.eupl12;
    platforms = platforms.linux;
  };
}
) {}