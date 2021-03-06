#
# Cookbook:: chef_habitat_wrapper
# Recipe:: default
#
# Copyright:: 2019, The Authors, All Rights Reserved.

# the hab_install resource is not 100% idempotent
# if habitat is installed at the right version
# but the hab user is not created, then the create
# user part of the resource is never run
if node['chef_habitat_wrapper']['create_user']
  group 'hab'

  user 'hab' do
    gid 'hab'
    system true
  end
end

hab_install 'install_habitat' do
  license node['chef_habitat_wrapper']['accept_license'].to_s == 'true' ? 'accept' : 'decline'
  install_url node['chef_habitat_wrapper']['install_url']
  create_user node['chef_habitat_wrapper']['create_user']
  action node['chef_habitat_wrapper']['install_action'].to_sym
end

if !node['chef_habitat_wrapper']['services'].empty? || node['chef_habitat_wrapper']['sup_action'] == 'run'
  hab_sup 'default' do
    extend ChefHabitatWrapper::UtilsHelpers
    bldr_url node['chef_habitat_wrapper']['bldr_url']
    permanent_peer node['chef_habitat_wrapper']['permanent_peer']
    listen_ctl param(node['chef_habitat_wrapper']['listen_ctl'])
    listen_gossip param(node['chef_habitat_wrapper']['listen_gossip'])
    listen_http param(node['chef_habitat_wrapper']['listen_http'])
    org node['chef_habitat_wrapper']['org']
    peer reduce_ip(node['chef_habitat_wrapper']['peer'], node)
    ring param(node['chef_habitat_wrapper']['ring'])
    hab_channel node['chef_habitat_wrapper']['sup_channel']
    auto_update node['chef_habitat_wrapper']['auto_update']
    license node['chef_habitat_wrapper']['accept_license'].to_s == 'true' ? 'accept' : 'decline'
    auth_token param(node['chef_habitat_wrapper']['sup_auth_token'])
    action node['chef_habitat_wrapper']['sup_action'].to_sym
  end
end

ruby_block 'wait_for_supervisor_to_start' do
  block do
    http_retry_count = Chef::Config['http_retry_count']
    Chef::Config['http_retry_count'] = 0
    count = 0
    addr = node['chef_habitat_wrapper']['listen_http'].nil? ?
      'http://127.0.0.1:9631' : node['chef_habitat_wrapper']['listen_http']

    until count == 5 do
      begin
        Chef::Log.debug "Trying to get supervisor census data from #{addr}. attempt #{count}"
        Chef::HTTP.new(addr).get('/census').inspect
      break
        rescue
        count += 1
        sleep 10
        next
      end
      Chef::Config['http_retry_count'] = http_retry_count
    end
  end
end

node['chef_habitat_wrapper']['packages'].each do |pkg, opt|
  hab_package pkg do
    extend ChefHabitatWrapper::UtilsHelpers
    bldr_url param(opt['bldr_url'], node['chef_habitat_wrapper']['bldr_url'])
    channel param(opt['channel'], node['chef_habitat_wrapper']['pkg_channel'])
    auth_token param(opt['auth_token'])
    binlink param(opt['binlink'], node['chef_habitat_wrapper']['pkg_binlink'], 'force')
    auth_token param(opt['auth_token']) 
    options param(opt['options'])
    version param(opt['version'])
    action param(opt['action'], node['chef_habitat_wrapper']['pkg_action'])
  end
end

node['chef_habitat_wrapper']['services'].each do |service, opt|
  if opt['user_toml_config']
    this_service = service.split("/")[1]
    hab_user_toml this_service do
      extend ChefHabitatWrapper::UtilsHelpers
      config(param(opt['user_toml_config'], {}))
      action param(opt['user_toml_action'], node['chef_habitat_wrapper']['user_toml_action']).to_sym
    end
  end
end

node['chef_habitat_wrapper']['services'].each do |service, opt|
  hab_service service do
    extend ChefHabitatWrapper::UtilsHelpers
    strategy param(opt['strategy'], node['chef_habitat_wrapper']['service_strategy'])
    topology param(opt['topology'], node['chef_habitat_wrapper']['service_topology'])
    bldr_url param(opt['bldr_url'], node['chef_habitat_wrapper']['bldr_url'])
    channel param(opt['channel'], node['chef_habitat_wrapper']['service_channel'])
    bind param(opt['bind'], [])
    binding_mode param(opt['binding_mode'], node['chef_habitat_wrapper']['binding_mode'])
    service_group param(opt['group'])
    remote_sup param(opt['remote_sup'], node['chef_habitat_wrapper']['remote_sup'])
    remote_sup_http param(opt['remote_sup_http'], node['chef_habitat_wrapper']['remote_sup_http'])
    action param(opt['service_action'], node['chef_habitat_wrapper']['service_action']).to_sym
  end
end

node['chef_habitat_wrapper']['services'].each do |service, opt|
  this_service = opt['group'].nil? ? "#{service.split("/")[1]}.default" : "#{service.split("/")[1]}.#{opt['group']}"
  hab_config this_service do
    extend ChefHabitatWrapper::UtilsHelpers
    config(param(opt['config'],{}))
    remote_sup param(opt['remote_sup'], node['chef_habitat_wrapper']['remote_sup'])
    remote_sup_http param(opt['remote_sup_http'], node['chef_habitat_wrapper']['remote_sup_http'])
    user param(opt['service_user'])
    action param(opt['config_action'], node['chef_habitat_wrapper']['config_action']).to_sym
  end
end
