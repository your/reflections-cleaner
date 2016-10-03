module ReflectionsCleaner
  def self.delete_dependent_records!(model_class, record_id)
    puts
    print "  Loading Eraser for #{model_class}, record ID: #{record_id}.. this might take a while.."
    eraser = Eraser.new(model_class, record_id)
    puts "done"
    puts

    eraser.delete_all_dependent_records! if eraser.allowed_to_proceed?
  end

  class Eraser
    def initialize(model_class, record_id)
      @ar_model = ARModel.new(model_class)
      @record_id = record_id
      @dependent_records = fetch_dependent_records
    end

    def allowed_to_proceed?
      puts "  Listing dependent records for AR model: '#{@ar_model.class_name}' with record ID: #{@record_id}"
      puts "-" * 80
      puts
      longest_tableized_and_pluralized_model_name_length = @dependent_records.map(&:first).max_by(&:length).length
      @dependent_records.each { |tableized_and_pluralized_model_name, records_to_delete|
        puts "   #{tableized_and_pluralized_model_name.ljust(longest_tableized_and_pluralized_model_name_length)} : #{records_to_delete.count}"
      }
      puts
      puts "-" * 80
      puts
      puts "  DANGER: YOU ARE ABOUT TO DELETE ALL THE RECORDS LISTED ABOVE.. **PERMANENTLY**."
      print "  DANGER: ARE YOU SURE TO PROCEED? [yN] "

      answer = gets.chomp

      return true if answer =~ /[yY]/
      false
    end

    def delete_all_dependent_records!
      puts
      @dependent_records.each { |tableized_and_pluralized_model_name, records_to_delete|
        print "  Deleting #{records_to_delete.count} #{tableized_and_pluralized_model_name}.. "
        print ActiveRecord::Base.logger.silence {
          if records_to_delete.any?
            tableized_and_pluralized_model_name.singularize.camelize.constantize.where("#{tableized_and_pluralized_model_name}.id IN (#{records_to_delete.join(', ')})").delete_all
          else
            0
          end
        }
        puts " deleted"
      }
      puts
      puts "  All done."
      puts
    end

    private

    def fetch_dependent_records
      @ar_model.dependent_records_for(@record_id)
    end

    class ARModel
      attr_reader :class_name

      def initialize(model_class)
        @class_name = model_class
      end

      def dependent_records_for(record_id)
        dependent_ar_models.map { |dependent_ar_model|
          tableized_and_pluralized_model_name = dependent_ar_model.to_s.tableize.pluralize
          [
            tableized_and_pluralized_model_name,
            ActiveRecord::Base.logger.silence { dependent_ar_model.where("#{tableized_and_pluralized_model_name}.#{foreign_key} = #{record_id.to_i}").pluck(:id) }
          ]
        }
      end

      private

      def foreign_key
        @foreign_key ||= @class_name.to_s.foreign_key
      end

      def has_many_reflections
        @class_name.reflect_on_all_associations.select { |reflection|
          reflection.class.name == "ActiveRecord::Reflection::HasManyReflection"
        }
      end

      def dependent_ar_models
        has_many_reflections.map { |has_many_reflection|
          (has_many_reflection.options[:class_name] || has_many_reflection.plural_name).camelize.singularize.constantize
        }
      end
    end
  end
end

# Example: ReflectionsCleaner.delete_dependent_records!(Venue, 5)

