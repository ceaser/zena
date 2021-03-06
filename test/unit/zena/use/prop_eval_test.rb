require 'test_helper'

class PropEvalTest < Zena::Unit::TestCase

  class NodesRoles < ActiveRecord::Base
    set_table_name :nodes_roles
  end

  context 'A visitor with admin rights' do
    setup do
      login(:lion)
    end

    context 'updating a virtual_class' do
      subject do
        secure(VirtualClass) { virtual_classes(:Letter) }
      end

      context 'with valid code' do
        should 'succeed' do
          # TODO: support queries as safe method directly on nodes (also change zena/use/query_builder.rb).
          # subject.update_attributes(:prop_eval => %q[{'title' => "#{paper} #{recipient.name}"}])
          subject.update_attributes(:prop_eval => %q[{'paper' => (paper.blank? ? 'Chiyogami' : paper), 'title' => 'booh'}])
        end
      end # with valid code

      context 'with syntax errors' do
        should 'fail' do
          assert !subject.update_attributes(:prop_eval => %q[{foo:#{tit}le} paper:#{paper}}])
          assert_match %r{parse error}, subject.errors[:prop_eval]
        end
      end # with syntax errors

      context 'with invalid final type' do
        should 'fail' do
          assert !subject.update_attributes(:prop_eval => %q[45])
          assert_equal 'Compilation should produce a Hash (Found Number).', subject.errors[:prop_eval]
        end
      end # with syntax errors
    end # updating a virtual_class
  end # A visitor with admin rights

  context 'A visitor with write access' do
    setup do
      login(:lion)
    end

    context 'creating a node from a class with eval prop' do
      subject do
        secure(Node) { Node.create_node(:class => 'Contact', :name => 'foo', :parent_id => nodes_zip(:projects)) }
      end

      should 'set evaluated prop on create' do
        assert_difference('Node.count', 1) do
          node = subject
          assert_equal ' foo', node.title
        end
      end
    end # creating a node from a class with eval prop


    context 'unpublishing a node from a class with eval prop' do
      subject do
        secure(Node) { nodes(:ant) }
      end

      should 'succeed' do
        assert subject.unpublish
      end
    end # unpublishing a node from a class with eval prop

    context 'on a node' do
      context 'from a class with evaluated properties' do
        subject do
          secure(Node) { nodes(:ant) }.tap do |n|
            n.update_attributes(:first_name => 'Dan', :name => 'Simmons')
          end
        end
        
        context 'updating attributes' do
          should 'update evaluated prop on save' do
            assert_equal 'Dan Simmons', subject.title
          end

          should 'use evaluated prop in fulltext indices' do
            assert_equal 'Dan Simmons', subject.version.idx_text_high
          end
          
          context 'with property indices' do
            subject do
              secure(Node) { nodes(:letter) }.tap do |n|
                assert n.update_attributes(:paper => 'Origami', :v_status => Zena::Status[:pub])
              end
            end

            should 'use evaluated prop in ml prop indices' do
              idx = IdxNodesMlString.find(:first, 
                :conditions => {:node_id => subject.id, :lang => visitor.lang, :key => 'search'}
              )
              assert_equal 'zena enhancements paper:Origami', idx.value
            end

            should 'use evaluated prop in prop indices' do
              idx = IdxNodesString.find(:first, 
                :conditions => {:node_id => subject.id, :key => 'search_mono'}
              )
              assert_equal 'Origami mono', idx.value
            end
          end # with property indices
          
        end # updating attributes
      end # from a class with evaluated properties

      context 'from a class with eval prop used as default' do
        setup do
          vclass = secure(Role) { roles(:Contact) }
          assert vclass.update_attributes(:prop_eval => %q[{'title' => (title.blank? ? 'Bikura' : title)}])
        end

        subject do
          secure(Node) { nodes(:ant) }
        end

        should 'not set default if not blank' do
          assert subject.update_attributes(:title => 'Super Man')
          assert_equal 'Super Man', subject.title
        end

        should 'set default if blank' do
          assert subject.update_attributes(:title => '')
          assert_equal 'Bikura', subject.title
        end
      end # from a class with eval prop used as default

      context 'from a native class' do
        subject do
          secure(Node) { nodes(:projects) }
        end

        should 'not raise on save' do
          assert_nothing_raised do
            assert subject.update_attributes(:title => 'Hyperion')
          end
          assert_equal 'Hyperion', subject.title
        end
      end # from a native class

    end # on a node
  end # A visitor with write access
end
