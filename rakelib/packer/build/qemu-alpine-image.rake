namespace :packer do
  namespace :build do
    desc 'Build the qemu-alpine image'
    task :'qemu-alpine-image' do
      require 'date'
      require 'open-uri'
      require 'yaml'
      require 'awesome_print'
      require 'facter'
      
      facts=Facter.to_hash

      datetime = DateTime.now.strftime('%Y%m%d-%H%M%S')

      image_name_base = 'qemu-alpine-image'
      packer_log_path_dir_template = 'logs/%<image_name_base>s'
      packer_log_path_dir = ::Kernel.format(
        packer_log_path_dir_template,
        image_name_base: image_name_base
      )
      packer_log_path_template = '%<packer_log_path_dir>s/log-%<datetime>s.log'
      packer_log_path = ::Kernel.format(
        packer_log_path_template,
        packer_log_path_dir: packer_log_path_dir,
        datetime: datetime
      )
      packer_project="tools/hashicorp/packer/images/#{image_name_base}"
      ::FileUtils.rm_rf   "output-qemu"
      ::FileUtils.mkdir_p 'run'
      ::FileUtils.mkdir_p "#{packer_project}/upload"
      ::FileUtils.mkdir_p packer_log_path_dir

      alpine_mirror='http://dl-cdn.alpinelinux.org'
      latest_releases_yaml=URI.parse("#{alpine_mirror}/alpine/latest-stable/releases/x86_64/latest-releases.yaml")
                              .read
      alpine_latest_virtual=YAML.load(latest_releases_yaml)
                                .select{|h| h['title'] == 'Virtual'}
                                .first

      qemu_accelerator = case facts.fetch('osfamily')
      when 'Linux'  then 'kvm'
      when 'Darwin' then 'hvf'
      else 'none'
      end
      qemu_registry='qemu-registry/'
      sh %W[
        PACKER_LOG=1
        PACKER_LOG_PATH=#{packer_log_path}
        packer build
        -var 'project_directory=#{packer_project}'
        -var 'image_name_base=#{image_name_base}'
        -var 'qemu_accelerator=#{qemu_accelerator}'
        -var 'alpine_mirror=#{alpine_mirror}'
        -var 'alpine_branch=#{alpine_latest_virtual.fetch('branch')}'
        -var 'alpine_version=#{alpine_latest_virtual.fetch('version')}'
        -var 'alpine_arch=#{alpine_latest_virtual.fetch('arch')}'
        -var 'alpine_iso=#{alpine_latest_virtual.fetch('iso')}'
        -var 'alpine_iso_sha512=#{alpine_latest_virtual.fetch('sha512')}'
        #{packer_project}/config-qemu.json
      && mv output-qemu/*.raw #{qemu_registry}
      ].join(' ')
    end
  end
end
