require 'rspec'
$:.unshift File.expand_path('../../', __FILE__)
require 'string_reader'
require 'active_mocker/table'
require 'active_mocker/reparameterize'
require 'active_mocker/field'
require 'active_mocker/active_record'
require 'active_mocker/model_reader'
require 'active_mocker/schema_reader'
require 'active_mocker/active_record/schema'
require 'active_mocker/base'
require 'active_support/all'

describe ActiveMocker::Base do

  let(:base_options){{}}
  let(:sub_options){{schema: {path: File.expand_path('../../', __FILE__), file_reader: schema_file},
                     model:  {path:  File.expand_path('../../', __FILE__), file_reader: model_file}}}

  let(:subject){ described_class.new(base_options.merge(sub_options))}

  let(:mock_class){subject.mock('Person')}

    let(:model_file){
      StringReader.new <<-eos
        class Person < ActiveRecord::Base
        end
      eos
    }

    let(:schema_file){
      StringReader.new <<-eos
        ActiveRecord::Schema.define(version: 20140327205359) do

              create_table "people", force: true do |t|
                t.integer  "company_id"
                t.string   "first_name",        limit: 128
                t.string   "middle_name",       limit: 128
                t.string   "last_name",         limit: 128
                t.string   "address_1",         limit: 200
                t.string   "address_2",         limit: 100
                t.string   "city",              limit: 100
                t.integer  "state_id"
                t.integer  "zip_code_id"
              end

            end
      eos
    }

  describe '#mock_class' do

    it 'create a mock object after the active record' do
      expect(mock_class).to eq(PersonMock)
    end

    context 'private methods' do

      let(:model_file){
        StringReader.new <<-eos
        class Person < ActiveRecord::Base
          private

          def bar
          end

        end
        eos
      }

      it 'will not have private methods' do
        expect{mock_class.bar}.to raise_error(NoMethodError)
      end

    end

    describe '#mock_of' do

      it 'return the name of the class that is being mocked' do
        expect(mock_class.new.mock_of).to eq 'Person'
      end

    end

    describe 'relationships' do

      let(:model_file){
        StringReader.new <<-eos
        class Person < ActiveRecord::Base
          belongs_to :account
        end
        eos
      }

      it 'add instance methods from model relationships' do
        result = mock_class.new(account: 'Account')
        expect(result.account).to eq 'Account'
      end

    end

    describe 'instance methods' do

      let(:model_file){
        StringReader.new <<-eos
        class Person < ActiveRecord::Base
          def bar(name, type=nil)
          end
        end
        eos
      }

      it 'will raise exception for unimplemented methods' do
        expect(mock_class.new.method(:bar).parameters).to eq  [[:req, :name], [:opt, :type]]
        expect{mock_class.new.bar}.to raise_error ArgumentError
        expect{mock_class.new.bar('foo', 'type')}.to raise_error('#bar is not Implemented for Class: PersonMock')
      end

      it 'can be implemented dynamically' do

        mock_class.instance_variable_set(:@bar, ->(name, type=nil){ "Now implemented with #{name} and #{type}" })
        result = mock_class.new
        result = result.bar('foo', 'type')
        expect(result).to eq "Now implemented with foo and type"

      end

      it 'can be implemented dynamically' do

        mock_class.mock_instance_method(:bar) do  |name, type=nil|
          "Now implemented with #{name} and #{type}"
        end

        result = mock_class.new
        result = result.bar('foo', 'type')
        expect(result).to eq "Now implemented with foo and type"

      end

    end

    describe 'class methods' do

      let(:model_file){
        StringReader.new <<-eos
        class Person < ActiveRecord::Base
          scope :named, -> { }

          def self.class_method
          end
        end
        eos
      }

      it 'will raise exception for unimplemented methods' do
        expect{mock_class.class_method}.to raise_error('::class_method is not Implemented for Class: PersonMock')
      end

      it 'can be implemented as follows' do
        mock_class.singleton_class.class_eval do
          define_method(:named) do
            'Now implemented'
          end
        end

        expect(mock_class.named).to eq "Now implemented"

      end

      it 'loads named scopes as class method' do
        expect{mock_class.named}.to raise_error('::named is not Implemented for Class: PersonMock')
      end

    end

  end

  describe '::column_names' do


    it 'returns an array of column names found from the schema.rb file' do
      expect(mock_class.column_names).to eq(["company_id", "first_name", "middle_name", "last_name", "address_1", "address_2", "city", "state_id", "zip_code_id"])
    end

  end


  describe 'have attributes from schema' do

    xit 'uses ActiveHash'

    xit 'makes plain ruby class' do

    end

  end

  describe 'mass_assignment' do



    it "can pass any or all attributes from schema in initializer" do
      result = mock_class.new(first_name: "Sam", last_name: 'Walton')
      expect(result.first_name).to eq 'Sam'
      expect(result.last_name).to eq 'Walton'

    end

    context 'set to false' do

      it 'will fail' do
        mock = described_class.new(sub_options.merge({mass_assignment: false}))
        person = mock.mock("Person")
        expect{
          person.new(first_name: "Sam", last_name: 'Walton')
        }.to raise_error ArgumentError
      end

    end

  end


end
