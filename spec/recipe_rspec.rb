#!/usr/bin/env ruby
# frozen_string_literal: true
#
# Copyright (C) 2016 Scarlett Clark <sgclark@kde.org>
#
# This library is free software; you can redistribute it and/or
# modify it under the terms of the GNU Lesser General Public
# License as published by the Free Software Foundation; either
# version 2.1 of the License, or (at your option) version 3, or any
# later version accepted by the membership of KDE e.V. (or its
# successor approved by the membership of KDE e.V.), which shall
# act as a proxy defined in Section 6 of version 3 of the license.
#
# This library is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
# Lesser General Public License for more details.
#
# You should have received a copy of the GNU Lesser General Public
# License along with this library.  If not, see <http://www.gnu.org/licenses/>.
require_relative '../libs/recipe'
require_relative '../libs/sources'
require 'yaml'
require 'erb'

metadata = YAML.load_file("/in/spec/metadata.yml")
deps = metadata['dependencies']
puts metadata

describe Recipe do
  app = Recipe.new(name: metadata['name'])
  describe "#initialize" do
    it "Sets the application name" do
      expect(app.name).to eq metadata['name']
    end
  end

  describe 'clean_workspace' do
    it "Cleans the environment" do
      unless Dir["/out/*"].empty? && Dir["/app/*"].empty?
        Dir.chdir('/')
        app.clean_workspace
      end
      expect(Dir["/app/*"].empty?).to be(true), "Please clean up from last build"
      expect(Dir["/out/*"].empty?).to be(true), "AppImage exists, please remove"
    end
  end

  describe 'install_packages' do
    it 'Installs distribution packages' do
      expect(app.install_packages(packages: metadata['packages'])).to be(0), " Expected 0 exit Status"
    end
  end

  describe 'build_non_kf5_dep_sources' do
    it 'Builds source dependencies that do not depend on kf5' do
      sources = Sources.new
      deps = metadata['dependencies']
      deps.each do |dep|
        name =  dep.values[0]['depname']
        type = dep.values[0]['source'].values_at('type').to_s.gsub(/\,|\[|\]|\"/, '')
        url = dep.values[0]['source'].values_at('url').to_s.gsub(/\,|\[|\]|\"/, '')
        buildsystem = dep.values[0]['build'].values_at('buildsystem').to_s.gsub(/\,|\[|\]|\"/, '')
        options = dep.values[0]['build'].values_at('buildoptions').to_s.gsub(/\,|\[|\]|\"/, '')
        autoreconf = dep.values[0]['build'].values_at('autoreconf').to_s.gsub(/\,|\[|\]|\"/, '')
        expect(sources.get_source(name, type, url)).to be(0), " Expected 0 exit Status"
        unless name == 'cpan'
          expect(Dir.exist?("/app/src/#{name}")).to be(true), "#{name} directory does not exist, something went wrong with source retrieval"
        end
        unless buildsystem == 'make'
          expect(sources.run_build(name, buildsystem, options)).to be(0), " Expected 0 exit Status"
        end
        if buildsystem == 'make'
          expect(sources.run_build(name, buildsystem, options, autoreconf)).to be(0), " Expected 0 exit Status"
        end
      end
    end
  end

  describe 'build_kf5' do
    it 'Builds KDE Frameworks from source' do
      sources = Sources.new
      system('pwd && ls')
      kf5 = metadata['frameworks']
      need = kf5['build_kf5']
      frameworks = kf5['frameworks']
      if need == true
        frameworks.each do |framework|
          if framework == 'phonon'
            options = '-DCMAKE_INSTALL_PREFIX:PATH=/app/usr -DBUILD_TESTING=OFF -DPHONON_BUILD_PHONON4QT5=ON'
            expect(sources.get_source(framework, 'git', "https://anongit.kde.org/#{framework}")).to be(0), "Expected 0 exit status"
            expect(Dir.exist?("/app/src/#{framework}")).to be(true), "#{framework} directory does not exist, something went wront with source retrieval"
            expect(sources.run_build(framework, 'cmake', options)).to be(0), " Expected 0 exit Status"
          else
            options = '-DCMAKE_INSTALL_PREFIX:PATH=/app/usr -DBUILD_TESTING=OFF'
            expect(sources.get_source(framework, 'git', "https://anongit.kde.org/#{framework}")).to be(0), "Expected 0 exit status"
            expect(Dir.exist?("/app/src/#{framework}")).to be(true), "#{framework} directory does not exist, something went wront with source retrieval"
            expect(sources.run_build(framework, 'cmake', options)).to be(0), " Expected 0 exit Status"
          end
        end
      end
    end
  end

    describe 'build_kf5_dep_sources' do
      it 'Builds source dependencies that depend on kf5' do
        sources = Sources.new
        kf5 = metadata['frameworks']
        need = kf5['build_kf5']
        frameworks = kf5['frameworks']
        if need == true
          deps = metadata['kf5_deps']
          if deps
            deps.each do |dep|
              name =  dep.values[0]['depname']
              type = dep.values[0]['source'].values_at('type').to_s.gsub(/\,|\[|\]|\"/, '')
              url = dep.values[0]['source'].values_at('url').to_s.gsub(/\,|\[|\]|\"/, '')
              buildsystem = dep.values[0]['build'].values_at('buildsystem').to_s.gsub(/\,|\[|\]|\"/, '')
              options = dep.values[0]['build'].values_at('buildoptions').to_s.gsub(/\,|\[|\]|\"/, '')
              expect(sources.get_source(name, type, url)).to be(0), " Expected 0 exit Status"
              expect(Dir.exist?("/app/src/#{name}")).to be(true), "#{name} directory does not exist, something went wrong with source retrieval"
              expect(sources.run_build(name, buildsystem, options)).to be(0), " Expected 0 exit Status"
            end
          end
        end
      end
    end


    describe 'build_project' do
        it 'Retrieves sources that need to be built from source' do
          #Main project
          sources = Sources.new
          name = metadata['name']
          type = metadata['type']
          url = metadata['url']
          buildsystem = metadata['buildsystem']
          options = metadata['buildoptions']
          expect(sources.get_source(name, type, url)).to be(0), " Expected 0 exit Status"
          expect(Dir.exist?("/app/src/#{name}")).to be(true), "#{name} directory does not exist, things will fail"
          expect(sources.run_build(name, buildsystem, options)).to be(0), " Expected 0 exit Status"
        end
    end

  def set_version(args = {})
    self.type = args[:type]
    self.url = args[:url]
    p "#{type}"
    Dir.chdir("/app/src/#{name}") do
      if  "#{type}" == 'git'
        self.version = `git describe`.chomp.gsub("release-", "").gsub(/-g.*/, "")
        p "#{version}"
      else
        self.version = "#{url}".chomp.("(^[\d.]+)")
      end
    end
  end


  # describe 'gather_integration' do
  #   it 'Gather and adjust desktop file' do
  #     name = app.name
  #     p name
  #     expect(app.gather_integration(desktop: 'firefox')).to be(0), " Expected 0 exit Status"
  #     expect(File.exist?("/app/firefox.desktop")).to be(true), "Desktop file does not exist, things will fail"
  #     #expect(File.readlines("/app/firefox.desktop").grep(/Icon/).size > 0).to be(true), "No Icon entry in desktop file will fail this operation."
  #   end
  # end
  #
  # describe 'copy_icon' do
  #   it 'Retrieves a suitable icon for integration' do
  #     expect(app.copy_icon(icon: 'emblem-web.png', iconpath:  '/usr/share/icons/gnome/48x48/emblems/')).to be(0), " Expected 0 exit Status"
  #     expect(File.exist?("/app/#{app.icon}")).to be(true), "Icon does not exist, things will fail"
  #   end
  # end

 #  describe 'run linuxdeployqt' do
 #     it 'Copies lib dependencies generated with ldd' do
 #      expect(app.run_linuxdeployqt()).to be(0), " Expected 0 exit Status"
 #     end
 #   end
 # end
#
#   describe 'run_integration' do
#     it 'Runs desktop integration to prepare app wrapper' do
#       expect(app.run_integration()).to be(0), " Expected 0 exit Status"
#       expect(File.exist?("/app/usr/bin/#{app.name}.wrapper")).to be(true), "Icon does not exist, things will fail"
#       expect(File.exist?("/app/AppRun")).to be(true), "AppRun missing, things will fail"
#     end
#   end
#
#   describe 'copy_dependencies' do
#     it 'Copies over system installed dependencies' do
#       expect(app.copy_dependencies(dep_path: metadata['dep_path'])).to be(0), " Expected 0 exit Status"
#       expect(File.exist?("/#{app.app_dir}/#{app.desktop}.desktop")).to be(true), "Desktop file does not exist, things will fail"
#       expect(File.exist?("/#{app.app_dir}/#{app.icon}")).to be(true), "Icon does not exist, things will fail"
#     end
#   end
#
#   describe 'copy_libs' do
#     it 'Copies lib dependencies generated with ldd' do
#       expect(app.copy_libs()).to be(0), " Expected 0 exit Status"
#     end
#   end
#
#   describe 'move_lib' do
#     it 'Moves /lib to ./usr/lib where appimage expects them' do
#       app.move_lib
#       expect(Dir["/#{app.app_dir}/lib/*"].empty?).to be(true), "Files still in lib, move them to usr"
#     end
#   end
#
#   describe 'delete_blacklisted' do
#     it 'Deletes blacklisted libraries' do
#       expect(app.delete_blacklisted()).to be(0), " Expected 0 exit Status"
#     end
#   end

  describe 'generate_appimage' do
    it 'Generate the appimage' do
      File.write('/in/Recipe', app.render)
      expect(app.generate_appimage()).to eq 0
      expect(File.exist?("/appimage/*.AppImage")).to be(true), "Something went wrong, no AppImage"
      app.clean_workspace
    end
  end
end
