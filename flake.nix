{
  description = "open source remake and fan expansion of Dungeon Keeper";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
  };

  outputs = { self, nixpkgs, ... }: let
    system = "x86_64-linux";
    pkgs = import nixpkgs {
      inherit system;
      config = {
        allowUnfree = true;
      };
    };
    inherit (pkgs) lib;

    astronomyTarball = pkgs.fetchurl {
      url = "https://github.com/dkfans/kfx-deps/releases/download/20250418/astronomy-lin64.tar.gz";
      sha256 = "sha256-fSvt1elwNbJiV8b1k+rySoU7zXKh2w2kqlZwa9+8DiI=";
    };

    centijsonTarball = pkgs.fetchurl {
      url = "https://github.com/dkfans/kfx-deps/releases/download/20250418/centijson-lin64.tar.gz";
      sha256 = "sha256-ukK1FGFAl42pCb/0/In7CcBk0xXE23blbf1RKE3dMp8";
    };

    enet6Tarball = pkgs.fetchurl {
      url = "https://github.com/dkfans/kfx-deps/releases/download/20260213/enet6-lin64.tar.gz";
      sha256 = "sha256-BGFdY/jlQGBMGV8upAB271GQMDFpUQSpWhxhOEfncvk=";
    };

    libcurlTarball = pkgs.fetchurl {
      url = "https://github.com/dkfans/kfx-deps/releases/download/20260310/libcurl-lin64.tar.gz";
      sha256 = "sha256-WqrHIuxKfPJMTBsCJ5c5Zh6c0y6FhkTbXdrmwRuLIOk=";
    };
    
    po2ngdat = pkgs.fetchFromGitHub {
      owner = "dkfans";
      repo = "po2ngdat";
      rev = "v1.0.2.31-d";
      hash = "sha256-Wm1TUymBow9FKkiG31WkTQxNZImJhO2ltjbYxjYxA2k=";
    };

    gogInstaller = pkgs.requireFile {
      name = "dungeon_keeper_setup.exe";
      sha256 = "sha256-3uDx5KQ4wnwIcnxAfmY1H0i7pXfDdJ9V9eQEhcj8aS4=";
      message = ''
        Original Dungeon Keeper assets are required to run KeeperFX. Please download
        the offline installer from Good Old Games and add it to the Nix store:

          lgogdownloader --download-file dungeon_keeper/en1installer0 -o dungeon_keeper_setup.exe
          nix-store --add-fixed sha256 dungeon_keeper_setup.exe
      '';
    };

    fullDist = pkgs.fetchurl {
      name = "keeperfx_1_4_0_complete.7z";
      url = "https://github.com/dkfans/keeperfx/releases/download/v1.4.0/keeperfx_1_4_0_complete.7z";
      sha256 = "sha256-gtnVY06Opsq7j2L71IMLdYkZiThjzTE1F68lajBAonk=";
    };

    sharedNativeBuildInputs = [
      pkgs.cmake
      pkgs.git
      pkgs.gnumake
      pkgs.ninja
      pkgs.p7zip
      pkgs.pkg-config
    ];

    sharedBuildInputs = [
      pkgs.alsa-lib
      pkgs.ffmpeg
      pkgs.libGL
      pkgs.libnatpmp
      pkgs.libspng
      pkgs.luajit
      pkgs.miniupnpc
      pkgs.minizip
      pkgs.openal
      pkgs.openssl
      pkgs.sdl3
      pkgs.sdl3-image
      pkgs.sdl3-mixer
      pkgs.zlib
      pkgs.zstd
    ];

    keeperfx = pkgs.stdenv.mkDerivation (finalAttrs: {
      pname = "keeperfx";
      version = "1.4.0-dev";
      src = ./.;

      __structuredAttrs = true;
      strictDeps = true;

      nativeBuildInputs = sharedNativeBuildInputs ++ [ po2ngdat ];
      buildInputs = sharedBuildInputs;

      preConfigure = ''
        mkdir -p build/deps dist

        ln -s ${astronomyTarball} build/deps/astronomy.tar.gz
        ln -s ${centijsonTarball} build/deps/centijson.tar.gz
        ln -s ${enet6Tarball}     build/deps/enet6.tar.gz
        ln -s ${libcurlTarball}   build/deps/libcurl.tar.gz

        cp -r ${po2ngdat} tools/po2ngdat
        chmod -R +w tools/po2ngdat

        ${pkgs.p7zip}/bin/7z x -odist ${fullDist} '-xr!*.exe' '-xr!*.dll' '-xr!*.txt' -x!keeperfx.cfg -ssc-
      '';

      postBuild = ''
        (cd .. && make pkg-assemble)
      '';

      postInstall = ''
        shopt -s extglob

        mkdir -p $out/bin $out/share/keeperfx

        mv $out/!(bin|share) $out/share/keeperfx/

        ${pkgs.innoextract}/bin/innoextract \
          -I "data/bluepal.dat" \
          -I "data/bluepall.dat" \
          -I "data/dogpal.pal" \
          -I "data/hitpall.dat" \
          -I "data/lightng.pal" \
          -I "data/redpal.col" \
          -I "data/redpall.dat" \
          -I "data/slab0-0.dat" \
          -I "data/slab0-1.dat" \
          -I "data/vampal.pal" \
          -I "data/whitepal.col" \
          -I "sound/atmos1.sbk" \
          -I "sound/atmos2.sbk" \
          -I "sound/bullfrog.sbk" \
          -I "keeper02.ogg" \
          -I "keeper03.ogg" \
          -I "keeper04.ogg" \
          -I "keeper05.ogg" \
          -I "keeper06.ogg" \
          -I "keeper07.ogg" \
          -g \
          -L \
          -d $out/share/keeperfx \
          "${gogInstaller}"

        cp --recursive --update=none --verbose --target-directory=$out/share/keeperfx/ ../dist/*

        mv $out/share/keeperfx/keeperfx.cfg $out/share/keeperfx/keeperfx.cfg.template
      '';

      doInstallCheck = false;

      meta = {
        description = "open source remake and fan expansion of Dungeon Keeper";
        homepage = "https://github.com/dkfans/keeperfx";
        license = lib.licenses.gpl2Plus;
        mainProgram = "keeperfx";
        platforms = lib.platforms.linux;
      };
    });

    keeperfxWrapper = pkgs.writeShellApplication {
      name = "keeperfx";
      
      runtimeInputs = [ pkgs.coreutils ];

      text = ''
        CONFIG_DIR="''${XDG_CONFIG_HOME:-$HOME/.config}/keeperfx"
        CONFIG_FILE="$CONFIG_DIR/keeperfx.cfg"

        mkdir -p "$CONFIG_DIR"
        if [ ! -f "$CONFIG_FILE" ]; then
            sed "s|^INSTALL_PATH=.*|INSTALL_PATH=${keeperfx}/share/keeperfx|" \
                "${keeperfx}/share/keeperfx/keeperfx.cfg.template" \
                > "$CONFIG_FILE"
            chmod +w "$CONFIG_FILE"
        fi

        "${keeperfx}/share/keeperfx/keeperfx" -config "$CONFIG_FILE" "$@"
      '';
    };
  in
  {
    packages.${system} = {
      inherit keeperfx keeperfxWrapper;
      default = keeperfxWrapper;
    };

    devShells.${system} = {
      default = pkgs.mkShell {
        nativeBuildInputs = sharedNativeBuildInputs;
        buildInputs = sharedBuildInputs;

        shellHook = ''
          export PS1="\n\[\033[1;32m\][\[\e]0;DEV:\w\a\]DEV:\w]\$\[\033[0m\] ";
        '';
      };
    };
  };
}
