app_libdir = File.expand_path(File.join(__dir__,'lib'))
$LOAD_PATH.unshift(app_libdir) unless $LOAD_PATH.include?(app_libdir)
Dir.glob('rakelib/**/*/').each { |rakelib| Rake.add_rakelib rakelib}

Rake::TaskManager.record_task_metadata = true

namespace :task do
  desc 'List available task'
  task :list do
    app = Rake.application
    app.tasks.each do |task|
      puts "%-20s  # %s" % [task.name, task.full_comment]
    end
  end
end
desc 'Run task:list'
task :default do
  Rake.application['task:list'].invoke()
end
