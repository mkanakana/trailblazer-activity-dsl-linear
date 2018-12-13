class Trailblazer::Activity
  module DSL
    # Implementing a specific DSL, simplified version of the {Magnetic DSL} from 2017.
    #
    # Produces {Implementation} and {Intermediate}.
    module Linear

      # Sequence
      class Sequence < Array
      end

      # Sequence
      module Search
        module_function

        # From this task onwards, find the next task that's "magnetic to" {target_color}.
        # Note that we only go forward, no back-references are done here.
        def Forward(output, target_color)
          ->(sequence, me) do
            target_seq_row = sequence[sequence.index(me)+1..-1].find { |seq_row| seq_row[0] == target_color }

            return output, target_seq_row
          end
        end

        def Noop(output)
          ->(sequence, me) do
            nil
          end
        end

        def ById(output, id)

        end
      end # Search

      # Sequence
      # Functions to mutate the Sequence by inserting, replacing, or deleting tasks.
      # These functions are called in {insert_task}
      module Insert
        module_function

        # Append {new_row} after {insert_id}.
        def Append(sequence, new_row, insert_id:, **)
          index, sequence = find(sequence, insert_id)

          sequence.insert(index+1, new_row)
        end

        # Insert {new_row} before {insert_id}.
        def Prepend(sequence, new_row, insert_id:, **)
          index, sequence = find(sequence, insert_id)

          sequence.insert(index, new_row)
        end

        # @private
        def find_index(sequence, insert_id)
          sequence.find_index { |seq_row| seq_row[3][:id] == insert_id }
        end

        def find(sequence, insert_id)
          return find_index(sequence, insert_id), sequence.clone # Ruby doesn't have an easy way to avoid mutating arrays :(
        end
      end

      module Compiler
        module_function

        # Default strategy to find out what's a stop event is to inspect the TaskRef's {data[:stop_event]}.
        def find_stop_task_refs(intermediate_wiring)
          intermediate_wiring.collect { |task_ref, outs| task_ref.data[:stop_event] ? task_ref : nil }.compact
        end

        # The first task in the wiring is the default start task.
        def find_start_task_refs(intermediate_wiring)
          [intermediate_wiring.first.first]
        end

        def call(sequence, find_stops: method(:find_stop_task_refs), find_start: method(:find_start_task_refs))
          _implementations, intermediate_wiring =
            sequence.inject([[], []]) do |(implementations, intermediates), seq_row|
              magnetic_to, task, connections, data = seq_row
              id = data[:id]

              # execute all {Search}s for one sequence row.
              connections = find_connections(seq_row, connections, sequence)

              implementations += [[id, Process::Implementation::Task(task, connections.collect { |output, _| output }) ]]

              intermediates += [[Process::Intermediate::TaskRef(id, data), connections.collect { |output, target_id| Process::Intermediate::Out(output.semantic, target_id) }] ]

              [implementations, intermediates]
            end

          start_task_refs = find_start.(intermediate_wiring)
          stop_task_refs = find_stops.(intermediate_wiring)

          intermediate   = Process::Intermediate.new(Hash[intermediate_wiring], stop_task_refs, start_task_refs)
          implementation = Hash[_implementations]

          Process::Intermediate.(intermediate, implementation)
        end

        # private

        def find_connections(seq_row, strategies, sequence)
          strategies.collect do |search|
            output, target_seq_row = search.(sequence, seq_row) # invoke the node's "connection search" strategy.
            next if output.nil? # FIXME.
raise "Couldn't find target for #{seq_row}" if target_seq_row.nil?
            [
              output,                                     # implementation
              target_seq_row[3][:id],  # intermediate
              target_seq_row # DISCUSS: needed?
            ]
          end.compact
        end
      end # Compiler
    end
  end
end

require "trailblazer/activity/path"
require "trailblazer/activity/railway"
require "trailblazer/activity/dsl/linear/helper" # FIXME

require "trailblazer/activity/dsl/linear/normalizer"
