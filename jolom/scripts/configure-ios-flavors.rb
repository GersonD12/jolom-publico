#!/usr/bin/env ruby
# frozen_string_literal: true

require 'xcodeproj'

project_path = File.expand_path('../ios/Runner.xcodeproj', __dir__)
project = Xcodeproj::Project.open(project_path)
runner = project.targets.find { |target| target.name == 'Runner' }
tests = project.targets.find { |target| target.name == 'RunnerTests' }
abort 'No se encontró el target Runner' unless runner

flavors = {
  'dev' => {
    'bundle_id' => 'com.example.jolom',
    'display_name' => 'Jolom Dev'
  },
  'prod' => {
    'bundle_id' => 'com.example.jolom.prod',
    'display_name' => 'Jolom'
  }
}.freeze

base_configurations = {
  'Debug' => :debug,
  'Profile' => :release,
  'Release' => :release
}.freeze

def clone_configuration(owner, source_name, destination_name, type)
  existing = owner.build_configurations.find { |configuration| configuration.name == destination_name }
  return existing if existing

  source = owner.build_configurations.find { |configuration| configuration.name == source_name }
  abort "No existe la configuración base #{source_name}" unless source

  destination = owner.add_build_configuration(destination_name, type)
  destination.build_settings.update(source.build_settings)
  destination.base_configuration_reference = source.base_configuration_reference
  destination
end

flutter_group = project.main_group.groups.find { |group| group.display_name == 'Flutter' }
abort 'No se encontró el grupo Flutter en Xcode' unless flutter_group

profile_path = 'Flutter/Profile.xcconfig'
profile_reference = flutter_group.files.find { |file| file.path == profile_path }
profile_reference ||= flutter_group.new_file(profile_path)
runner.build_configurations.find { |configuration| configuration.name == 'Profile' }
      .base_configuration_reference = profile_reference

xcconfig_refs = {}
flavors.each_key do |flavor|
  base_configurations.each_key do |base_name|
    configuration_name = "#{base_name}-#{flavor}"
    path = "Flutter/#{configuration_name}.xcconfig"
    reference = flutter_group.files.find { |file| file.path == path }
    xcconfig_refs[configuration_name] = reference || flutter_group.new_file(path)
  end
end

flavors.each do |flavor, values|
  base_configurations.each do |base_name, type|
    configuration_name = "#{base_name}-#{flavor}"
    clone_configuration(project, base_name, configuration_name, type)

    runner_configuration = clone_configuration(runner, base_name, configuration_name, type)
    runner_configuration.base_configuration_reference = xcconfig_refs.fetch(configuration_name)
    runner_configuration.build_settings['APP_ENV'] = flavor
    runner_configuration.build_settings['APP_DISPLAY_NAME'] = values.fetch('display_name')
    runner_configuration.build_settings['PRODUCT_BUNDLE_IDENTIFIER'] = values.fetch('bundle_id')

    next unless tests

    test_configuration = clone_configuration(tests, base_name, configuration_name, type)
    test_configuration.build_settings['PRODUCT_BUNDLE_IDENTIFIER'] = "#{values.fetch('bundle_id')}.RunnerTests"
  end
end

# El plist ya no se agrega como recurso fijo; una fase selecciona el correcto.
google_plists = project.files.select do |file|
  File.basename(file.path.to_s) == 'GoogleService-Info.plist'
end
google_plists.each do |file|
  project.objects.grep(Xcodeproj::Project::Object::PBXBuildFile)
         .select { |build_file| build_file.file_ref == file }
         .each(&:remove_from_project)
  file.remove_from_project
end

phase = runner.shell_script_build_phases.find do |build_phase|
  build_phase.name == 'Select Firebase configuration'
end
phase ||= runner.new_shell_script_build_phase('Select Firebase configuration')
phase.shell_path = '/bin/sh'
phase.input_paths = ['$(PROJECT_DIR)/config/$(APP_ENV)/GoogleService-Info.plist']
phase.output_paths = ['$(TARGET_BUILD_DIR)/$(UNLOCALIZED_RESOURCES_FOLDER_PATH)/GoogleService-Info.plist']
phase.shell_script = <<~'SH'
  set -eu

  source_plist="${PROJECT_DIR}/config/${APP_ENV}/GoogleService-Info.plist"
  destination_plist="${TARGET_BUILD_DIR}/${UNLOCALIZED_RESOURCES_FOLDER_PATH}/GoogleService-Info.plist"

  if [ ! -f "$source_plist" ]; then
    echo "error: Falta $source_plist. Ejecuta make firebase-${APP_ENV}." >&2
    exit 1
  fi

  configured_bundle_id="$(/usr/libexec/PlistBuddy -c 'Print :BUNDLE_ID' "$source_plist" 2>/dev/null || true)"
  if [ "$configured_bundle_id" != "$PRODUCT_BUNDLE_IDENTIFIER" ]; then
    echo "error: Firebase usa $configured_bundle_id, pero el build usa $PRODUCT_BUNDLE_IDENTIFIER." >&2
    exit 1
  fi

  reversed_client_id="$(/usr/libexec/PlistBuddy -c 'Print :REVERSED_CLIENT_ID' "$source_plist" 2>/dev/null || true)"
  if [ -z "${GOOGLE_REVERSED_CLIENT_ID:-}" ] || [ "$reversed_client_id" != "$GOOGLE_REVERSED_CLIENT_ID" ]; then
    echo "error: REVERSED_CLIENT_ID no coincide. Ejecuta make firebase-${APP_ENV}." >&2
    exit 1
  fi

  mkdir -p "$(dirname "$destination_plist")"
  cp "$source_plist" "$destination_plist"
SH

project.save
puts 'Flavors iOS dev/prod configurados.'
