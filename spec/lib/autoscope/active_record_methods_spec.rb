require 'spec_helper'

module Autoscope

  describe ActiveRecord do

    before(:all) do

      Object.const_set('Post', Class.new(ActiveRecord::Base))

      Post.connection.create_table(:posts, force: true) do |t|
        t.string :title
        t.text :body
        t.integer :user_id
        t.string :protected_field
        t.string :private_field
        t.timestamps
      end

      Post.class_eval do

        scope :blank_arg_scope, -> user_id {
          where(user_id: user_id)
        }

        scope :user_id_scope, -> user_id {
          where(user_id: user_id)
        }
        scope :vararg_scope, -> *ids {
          where(['id IN (?)', args.flatten])
        }
        scope :two_param_scope, -> id1, id2 {
          where(['id IN (?)', [id1, id2]])
        }
        scope :no_param_scope, -> { where('x = 1') }
        scope :empty_lambda_scope, -> { where(['date > ?', Date.today]) }
        scope :optional_arg_scope, -> a, b = 5 { }

        protected_scope :nonsense, -> id, test { where(user_id: id) }

      end

      ActiveRecord::Base.connection.create_table(:users, force: true) do |t|
        t.string :name
        t.date :bday
        t.string :type
        t.timestamps
      end

      Object.const_set('User', Class.new(ActiveRecord::Base))

      User.class_eval do

        scope :by_name, lambda { |name|
          where(name: name)
        }

      end

      Object.const_set('Admin', Class.new(User))

    end

    context '.add_scopes' do

      it 'does not include scopes from other classes in its definition' do
        expect(User.scope_definition.keys).to eql([:by_name])
      end


      it 'adds all types of scopes to the supplied collection' do

        scope = Post.all

        scope.expects(:user_id_scope)
          .with('1')
          .returns(scope)

        scope.expects(:two_param_scope)
          .with('1', '2')
          .returns(scope)

        scope.expects(:vararg_scope)
          .with('1', '2', '3')
          .returns(scope)

        scope.expects(:optional_arg_scope)
          .with('req')
          .returns(scope)

        scope.expects(:blank_arg_scope).never

        Post.add_scopes(
          {
            blank_arg_scope: { user_id: '' },
            user_id_scope: { user_id: '1' },
            two_param_scope: {
              id1: '1',
              id2: '2'
            },
            vararg_scope: { ids: %w{1 2 3} },
            optional_arg_scope: { a: 'req' },
          },
          scope
        )

      end

      context 'Type filter' do

        it 'applies a filter on the type when a type key is passed in' do
          scope = User.add_scopes(type: 'Admin')
          expect(scope.where_values_hash[:type]).to eql(['Admin'])
        end

        it 'handles invalid class names' do
          expect {
            scope = User.add_scopes(type: 'InvalidClass')
          }.not_to raise_error
        end

        it 'merges with the scope that was passed in' do
          scope = User.add_scopes({ type: 'Admin' }, User.where(name: 'Dan'))

          where_values = scope.where_values_hash.with_indifferent_access

          expect(where_values["name"]).to eql('Dan')
          expect(where_values["type"]).to eql(['Admin'])
        end

        it 'does not apply a scope unless a descendant class is supplied' do
          original_scope = User.where(name: 'Dan')
          scope = User.add_scopes({ type: 'Post' }, original_scope)

          # shouldn't do anything
          expect(scope).to eql(original_scope)
        end

      end

      context '.register_scopes' do

        before :all do
          Post.class_eval do

            has_scopes :blah

            def self.blah
              where(user_id: 1)
            end
          end
        end

        it 'registers a class method as a scope' do
          expect(Post.scope_definition.keys).to include :blah
        end

        it 'constructs the proper query' do
          expect(Post.blah).to eq(Post.add_scopes(blah: true))
        end

      end



      context 'Pagination' do

        it 'adds pagination' do

          scope = Post.all

          scope.expects(:paginate)
            .with(page: 3, per_page: 20)
            .returns(scope)

          Post.add_scopes({ page: 3, per_page: 20 }, scope)

        end

      end

    end

  end

end