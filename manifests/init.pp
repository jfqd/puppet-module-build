# Debian/nexenta specific build module
#
# build::install { 'top':
#   download => 'http://www.unixtop.org/dist/top-3.7.tar.gz',
#   creates  => '/usr/local/bin/top',
# }

define build::install ($download, $creates, $pkg_folder='', $pkg_format="tar", $pkg_extension="", $buildoptions="", $extractorcmd="", $rm_build_folder=true) {
  
  if defined( Package['build-essential'] ) {
    debug("Package build-essential already installed")
  } else {
    package { 'build-essential': ensure => installed }
  }
  
  Exec {
    unless => "$test -f $creates",
  }
  
  $cwd    = "/usr/local/src"
  
  $test   = "/usr/bin/test"
  $unzip  = "/usr/bin/unzip"
  $tar    = "/usr/sbin/tar"
  $bunzip = "/usr/bin/bunzip2"
  $gunzip = "/usr/bin/gunzip"
  
  $filename = basename($download)
  
  $extension = $pkg_format ? {
    zip     => ".zip",
    bzip    => ".tar.bz2",
    tar     => ".tar.gz",
    default => $pkg_extension,
  }
  
  $foldername = $pkg_folder ? {
    ''      => gsub($filename, $extension, ""),
    default => $pkg_folder,
  }
  
  $extractor = $pkg_format ? {
    zip     => "$unzip -q -d $cwd $cwd/$filename",
    bzip    => "$bunzip -c $cwd/$filename | $tar -xf -",
    tar     => "$gunzip < $cwd/$filename | $tar -xf -",
    default => $extractorcmd,
  }
  
  exec { "download-$name":
    cwd     => "$cwd",
    command => "/usr/bin/wget -q $download",
    timeout => 120, # 2 minutes
  }
  
  exec { "extract-$name":
    cwd     => "$cwd",
    command => "$extractor",
    timeout => 120, # 2 minutes
    require => Exec["download-$name"],
  }
  
  exec { "config-$name":
    cwd     => "$cwd/$foldername",
    command => "$cwd/$foldername/configure $buildoptions",
    timeout => 120, # 2 minutes
    require => Exec["extract-$name"],
  }
  
  exec { "make-install-$name":
    cwd     => "$cwd/$foldername",
    command => "/usr/bin/make && /usr/bin/make install",
    timeout => 600, # 10 minutes
    require => Exec["config-$name"],
  }
  
  # remove build folder
  case $rm_build_folder {
    true: {
      notice("remove build folder")
      exec { "remove-$name-build-folder":
        cwd     => "$cwd",
        command => "/usr/bin/rm -rf $cwd/$foldername",
        require => Exec["make-install-$name"],
      } # exec
    } # true
  } # case
  
}