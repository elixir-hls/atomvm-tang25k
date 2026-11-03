#!/usr/bin/env python3

# Git repositories ---------------------------------------------------------------------------------

# Get SHA1: git rev-parse HEAD

class GitRepo:
    def __init__(self, url, clone="regular", develop=True, editable=True, sha1=None, branch="master",
        tag=None):
        assert clone in ["regular", "recursive"]
        self.url      = url
        self.clone    = clone
        self.develop  = develop
        self.editable = editable
        self.sha1     = sha1
        self.branch   = branch
        self.tag      = tag


git_repos = {
    "migen": GitRepo(url="https://git.m-labs.hk/M-Labs/", clone="recursive", editable=False, sha1="4c2ae8dfeea37f235b52acb8166f12acaaae4f7c"),
    "pythondata-software-picolibc": GitRepo(url="https://github.com/litex-hub/", clone="recursive", sha1="6a13ccce7c575b32c102dd9dc52178505b81fe39"),
    "pythondata-software-compiler_rt": GitRepo(url="https://github.com/litex-hub/", sha1="6eb76609c9627bf26635e57c63fb22cda7115887"),
    "litex": GitRepo(url="https://github.com/enjoy-digital/", sha1="b6ae9e0b227354aecffef5339d3e946f2395ac09", tag=True),
    "liteiclink": GitRepo(url="https://github.com/enjoy-digital/", sha1="db6e8fc9879fca14337b512c4a598720b63d76ec", tag=True),
    "liteeth": GitRepo(url="https://github.com/enjoy-digital/", sha1="85901f7f8bb8c3a52b3b8fbd4ee56947da3a6a99", tag=True),
    "litedram": GitRepo(url="https://github.com/enjoy-digital/", sha1="c454a440ca94afd57bca148a0ba2af491325f0e6", tag=True),
    "litepcie": GitRepo(url="https://github.com/enjoy-digital/", sha1="671aa895acdb96015ce841cc730579c0f2b678a3", tag=True),
    "litesata": GitRepo(url="https://github.com/enjoy-digital/", sha1="01f314a0704f407f753d97bba159cb0df4696f72", tag=True),
    "litesdcard": GitRepo(url="https://github.com/enjoy-digital/", sha1="17718d9258ac2dd62ac23e2eecd7ac613a050986", tag=True),
    "litescope": GitRepo(url="https://github.com/enjoy-digital/", sha1="807d953bf2f838e0a7af17dcb3c7724e0de2d623", tag=True),
    "litejesd204": GitRepo(url="https://github.com/enjoy-digital/", sha1="a1d0cbf27f5e386bfcad2190c82677024fc949bd", tag=True),
    "litedsp": GitRepo(url="https://github.com/enjoy-digital/", sha1="102e415425f60ba21b59972660d56c649612c080", branch="main"),
    "litespi": GitRepo(url="https://github.com/litex-hub/", sha1="1efda7b0ffe48068239e9a3b559d29c94c83fcf2", tag=True),
    "litei2c": GitRepo(url="https://github.com/litex-hub/", sha1="73ac32ef3fce0f31c047aeede19964d0aebc036e", branch="main", tag=True),
    "litex-boards": GitRepo(url="https://github.com/litex-hub/", sha1="e4307929c38a7d698c96c9a741af08ab1f2c183d", tag=True),
    "pythondata-misc-tapcfg": GitRepo(url="https://github.com/litex-hub/", sha1="a12c3f592c99f9c082fdc68c065b81cbd6e6b238"),
    "pythondata-misc-usb_ohci": GitRepo(url="https://github.com/litex-hub/", clone="recursive", sha1="17c1d3d6548ea267e19aec3cb6d2e64335a1bb2a"),
    "pythondata-cpu-lm32": GitRepo(url="https://github.com/litex-hub/", sha1="0f1d1b91202b95a9b749a745848430d64afb4400"),
    "pythondata-cpu-mor1kx": GitRepo(url="https://github.com/litex-hub/", sha1="ba6ea16dc1250ac138ea0d923af4f91da790892f"),
    "pythondata-cpu-minerva": GitRepo(url="https://github.com/litex-hub/", sha1="ab328774891c70694c6576be19d1d3e427d9f435"),
    "pythondata-cpu-naxriscv": GitRepo(url="https://github.com/litex-hub/", sha1="20da269306bb3bfabd09de08d4c1be1fbc202474"),
    "pythondata-cpu-sentinel": GitRepo(url="https://github.com/litex-hub/", sha1="7ec5e1e5db1a53910e4c58ae4c098ebce3f9591f", branch="main"),
    "pythondata-cpu-serv": GitRepo(url="https://github.com/litex-hub/", sha1="111947d7ab652c28642d7ff0a528dae293ca4601"),
    "pythondata-cpu-veer_eh1": GitRepo(url="https://github.com/litex-hub/", sha1="8d01ede7ea2ff40d4526616b0e2c91de0142508e", branch="main"),
    "pythondata-cpu-vexiiriscv": GitRepo(url="https://github.com/litex-hub/", sha1="15cfab529a17c473d0fc75edf3f409eb374cef35", branch="main"),
    "pythondata-cpu-vexriscv": GitRepo(url="https://github.com/litex-hub/", sha1="642ecfed1c84460555d6d803d660cc60cfc1ecb6"),
    "pythondata-cpu-vexriscv-smp": GitRepo(url="https://github.com/litex-hub/", clone="recursive", sha1="217d23d7e9ad5556c17a73dc6ffc1971765f3d7c"),
}

# Installs -----------------------------------------------------------------------------------------

frozen_repos = ['migen', 'pythondata-software-picolibc', 'pythondata-software-compiler_rt', 'litex', 'liteiclink', 'liteeth', 'litedram', 'litepcie', 'litesata', 'litesdcard', 'litescope', 'litejesd204', 'litedsp', 'litespi', 'litei2c', 'litex-boards', 'pythondata-misc-tapcfg', 'pythondata-misc-usb_ohci', 'pythondata-cpu-lm32', 'pythondata-cpu-mor1kx', 'pythondata-cpu-minerva', 'pythondata-cpu-naxriscv', 'pythondata-cpu-sentinel', 'pythondata-cpu-serv', 'pythondata-cpu-veer_eh1', 'pythondata-cpu-vexiiriscv', 'pythondata-cpu-vexriscv', 'pythondata-cpu-vexriscv-smp']

# Reuse the frozen set for every install config.
minimal_repos  = frozen_repos
standard_repos = frozen_repos
full_repos     = frozen_repos

install_configs = {
    "minimal"  : minimal_repos,
    "standard" : standard_repos,
    "full"     : full_repos,
}
