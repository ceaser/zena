require 'test_helper'

class ColumnTest < Zena::Unit::TestCase

  context 'A column' do
    setup do
      login(:lion)
    end

    subject do
      secure(Column) { columns(:Task_assigned) }
    end

    should 'return Role on role' do
      assert_kind_of Role, subject.role
    end

    should 'return kpath on kpath' do
      assert_equal 'N', subject.kpath
    end
  end # A column

  context 'Creating a column' do
    subject do
      Column.create(:role_id => roles_id(:Task), :ptype => 'string', :name => 'foo')
    end

    should 'create column' do
      assert_difference('Column.count', 1) do
        subject
      end
    end

    should 'set site_id' do
      subject
      assert_equal sites_id(:zena), subject.site_id
    end


    context 'with an existing name' do
      subject do
        Column.create(:role_id => roles_id(:Task), :ptype => 'string', :name => 'origin')
      end

      should 'fail with an error' do
        assert_difference('Column.count', 0) do
          assert_equal 'has already been taken', subject.errors[:name]
        end
      end
    end # with an existing name

    context 'with the name of a hardwire property' do
      subject do
        Column.create(:role_id => roles_id(:Task), :ptype => 'string', :name => 'title')
      end

      should 'fail with an error' do
        assert_difference('Column.count', 0) do
          assert_equal 'has already been taken in Node', subject.errors[:name]
        end
      end
    end # with the name of a hardwire property

    context 'with the name of a method in a model' do
      subject do
        Column.create(:role_id => roles_id(:Task), :ptype => 'string', :name => 'secure_on_destroy')
      end

      should 'fail with an error and return class' do
        assert_difference('Column.count', 0) do
          assert_equal 'invalid (method defined in Node)', subject.errors[:name]
        end
      end
    end # with the name of a hardwire property
    
    context 'ending with _ids' do
      subject do
        Column.create(:role_id => roles_id(:Task), :ptype => 'string', :name => 'secure_on_destroy_ids')
      end

      should 'fail with an error and return class' do
        assert_difference('Column.count', 0) do
          assert_equal 'invalid (cannot end with _id or _ids)', subject.errors[:name]
        end
      end
    end # with the name of a hardwire property
    
    context 'ending with _id' do
      subject do
        Column.create(:role_id => roles_id(:Task), :ptype => 'string', :name => 'secure_on_destroy_id')
      end

      should 'fail with an error and return class' do
        assert_difference('Column.count', 0) do
          assert_equal 'invalid (cannot end with _id or _ids)', subject.errors[:name]
        end
      end
    end # with the name of a hardwire property
  end # Creating a column

end
