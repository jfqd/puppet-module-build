# Debian/nexenta specific build module
#
# build::install { 'top':
#   file => 'http://www.unixtop.org/dist/top-3.7.tar.gz',
#   creates  => '/usr/local/bin/top',
# }

define build::install (
  $file,
  $creates,
  $pkg_folder         = '',
  $pkg_format         = 'tar',
  $pkg_extension      = '',
  $build_options      = '',
  $extractor_cmd      = '',
  $extract_options    = '',
  $make_cmd           = '',
  $src_cwd            = '/usr/local/src',
  $rm_build_folder    = true
  ) {

  if $file == undef {
    fail('parameter $file not set')
  }

  $filename = basename($file)
  $extratable_file = "${src_cwd}/${filename}"

  Exec {
    unless => "test -f ${creates}",
    path => [ "/bin/", "/sbin/" , "/usr/bin/", "/usr/sbin/" ]
  }
  
  $extension = $pkg_format ? {
    'zip'     => ".zip",
    'bzip'    => ".tar.bz2",
    'tar'     => ".tar.gz",
    default   => $pkg_extension,
  }
  
  $foldername = $pkg_folder ? {
    ''      => gsub($filename, $extension, ""),
    default => $pkg_folder,
  }

  ensure_resource('package', 'build-essential', {'ensure' => 'present' })
  ensure_resource('package', 'wget', {'ensure' => 'present' })

  if $file =~ /^http/ {
    notice("downloading ${file}")
    exec { "download-${name}":
      cwd     => $src_cwd,
      command => "wget -q ${file}",
      timeout => 120, # 2 minutes
      before  => Exec["extract-${name}"],
    }
  } else {
    notice("copying local file ${file}")
    file { "${extratable_file}":
      ensure  => present,
      source  => $file,
      before  => Exec["extract-${name}"],
    }
  }

  $extractor = $pkg_format ? {
    'zip'     => "unzip -q ${extract_options} -d ${src_cwd} ${extratable_file}",
    'bzip'    => "bunzip2 -c ${extratable_file} | tar ${extract_options} -xf -",
    'tar'     => "gunzip < ${extratable_file} | tar ${extract_options} -xf -",
    default   => $extractor_cmd,
  }

  exec { "extract-${name}":
    cwd     => $src_cwd,
    command => $extractor,
    timeout => 120, # 2 minutes,
  }

  exec { "config-${name}":
    cwd     => "${src_cwd}/${foldername}",
    command => "${src_cwd}/${foldername}/configure ${buildoptions}",
    timeout => 120, # 2 minutes
    require => Exec["extract-${name}"],
  }
  
  $make = $make_cmd ? {
    ''      => 'make && make install',
    verbose => true,
    default => $make_cmd,
  }

  exec { "make-install-${name}":
    cwd     => "${src_cwd}/${foldername}",
    command => $make,
    timeout => 600, # 10 minutes
    require => Exec["config-${name}"],
  }
  
  if str2bool($rm_build_folder) {
    notice('remove build folder')

    exec { "remove-${name}-build-folder":
      cwd     => $src_cwd,
      command => "rm -rf ${src_cwd}/${foldername}",
      require => Exec["make-install-${name}"],
    }
  }
}