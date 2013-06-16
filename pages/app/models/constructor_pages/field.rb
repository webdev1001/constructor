# encoding: utf-8

module ConstructorPages
  class Field < ActiveRecord::Base
    TYPES = %w{string integer float boolean text date html image}

    attr_accessible :name, :code_name, :type_value, :template_id, :template
    validates_presence_of :name
    validates_uniqueness_of :code_name, :scope => :template_id
    validate :method_uniqueness

    after_create :create_page_fields
    after_destroy :destroy_all_page_fields

    belongs_to :template

    TYPES.each do |t|
      class_eval %{
        has_one :#{t}_type, class_name: 'Types::#{t.titleize}Type'
      }
    end

    has_many :pages, through: :template

    acts_as_list  scope: :template_id
    default_scope order: :position

    # return constant of model by type_value
    def type_model; "constructor_pages/types/#{type_value}_type".classify.constantize end

    # remove all type_fields values for specified page
    def remove_values_for(page); type_model.destroy_all field_id: id, page_id: page.id end

    def update_value(page, params)
      _type_value = type_model.where(field_id: id, page_id: page.id).first_or_create

      if params
        _type_value.value = 0 if type_value == 'boolean'

        if params[type_value]
          if type_value == 'date'
            value = params[type_value][id.to_s]
            _type_value.value = Date.new(value['date(1i)'].to_i, value['date(2i)'].to_i, value['date(3i)'].to_i).to_s
          else
            _type_value.value = params[type_value][id.to_s]
          end
        end

        _type_value.save
      end
    end

    private

    def method_uniqueness
      if Page.first.respond_to?(code_name) \
      or Page.first.respond_to?(code_name.pluralize) \
      or Page.first.respond_to?(code_name.singularize) \
      or template.self_and_ancestors.map{|t| t.code_name unless t.code_name == code_name}.include?(code_name.pluralize) \
      or template.self_and_ancestors.map{|t| t.code_name unless t.code_name == code_name}.include?(code_name.singularize) \
      or template.descendants.map{|t| t.code_name unless t.code_name == code_name}.include?(code_name.pluralize) \
      or template.descendants.map{|t| t.code_name unless t.code_name == code_name}.include?(code_name.singularize)
        errors.add(:base, 'Такой метод уже используется')
      end
    end

    %w{create destroy_all}.each do |m|
      class_eval %{
          def #{m}_page_fields
            pages.each {|page| type_model.#{m} page_id: page.id, field_id: id}
          end
      }
    end
  end
end