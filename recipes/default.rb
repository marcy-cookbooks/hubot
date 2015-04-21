#
# Cookbook Name:: hubot
# Recipe:: default
#
# Copyright (c) 2013, Seth Chisamore
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#    http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#

include_recipe 'git'
include_recipe 'supervisor'
include_recipe 'nodejs'

user node['hubot']['user'] do
  comment 'Hubot User'
  home node['hubot']['install_dir']
end

group node['hubot']['group'] do
  members [node['hubot']['user']]
end

directory node['hubot']['install_dir'] do
  owner node['hubot']['user']
  group node['hubot']['group']
  recursive true
  mode '0755'
end

# https://github.com/github/hubot/archive/v2.4.6.zip
#checkout_location = node['hubot']['install_dir']
checkout_location = ::File.join(Chef::Config[:file_cache_path], 'hubot')
git checkout_location do
  repository 'https://github.com/github/hubot.git'
  revision "v#{node['hubot']['version']}"
  action :checkout
  notifies :run, 'execute[build and install hubot]', :immediately
end

execute 'build and install hubot' do
  command <<-EOH
npm install
chown #{node['hubot']['user']}:#{node['hubot']['group']} -R #{node['hubot']['install_dir']}
  EOH
  cwd checkout_location
  environment(
    'PATH' => "#{checkout_location}/node_modules/.bin:#{ENV['PATH']}"
  )
  action :nothing
end

template "#{node['hubot']['install_dir']}/package.json" do
  source 'package.json.erb'
  owner node['hubot']['user']
  group node['hubot']['group']
  mode '0644'
  variables node['hubot'].to_hash
  notifies :run, 'execute[npm install]', :immediately
end

template "#{node['hubot']['install_dir']}/hubot-scripts.json" do
  source 'hubot-scripts.json.erb'
  owner node['hubot']['user']
  group node['hubot']['group']
  mode '0644'
  variables node['hubot'].to_hash
  notifies :restart, 'supervisor_service[hubot]'
end

template "#{node['hubot']['install_dir']}/external-scripts.json" do
  source 'external-scripts.json.erb'
  owner node['hubot']['user']
  group node['hubot']['group']
  mode '0644'
  variables node['hubot'].to_hash
  notifies :restart, 'supervisor_service[hubot]'
end

execute 'npm install' do
  cwd node['hubot']['install_dir']
  user node['hubot']['user']
  group node['hubot']['group']
  environment(
    'USER' => node['hubot']['user'],
    'HOME' => node['hubot']['install_dir']
  )
  action :nothing
  notifies :restart, 'supervisor_service[hubot]'
end

node.override['hubot']['config']['PATH'] = "#{node['hubot']['install_dir']}/node_modules/.bin:%(ENV_PATH)s"

supervisor_service 'hubot' do
  command "#{node['hubot']['install_dir']}/node_modules/.bin/hubot --name '#{node['hubot']['name']}' --adapter #{node['hubot']['adapter']}"
  user node['hubot']['user']
  directory node['hubot']['install_dir']
  environment node['hubot']['config']
end
