require "test_helper"

#:intermediate
  def a(x=1)
  end
#:intermediate end

class LinearTest < Minitest::Spec
  Right = Class.new#Trailblazer::Activity::Right
  Left = Class.new#Trailblazer::Activity::Right
  PassFast = Class.new#Trailblazer::Activity::Right

  Process = Trailblazer::Activity::Process
  Inter = Trailblazer::Activity::Process::Intermediate
  Activity = Trailblazer::Activity

  Linear = Trailblazer::Activity::DSL::Linear

  let(:implementing) do
    implementing = Module.new do
      extend T.def_tasks(:a, :b, :c, :d, :f, :g)
    end
    implementing::Start = Activity::Start.new(semantic: :default)
    implementing::Failure = Activity::End(:failure)
    implementing::Success = Activity::End(:success)

    implementing
  end

  it do
    # generated by the editor or a specific DSL.
    # DISCUSS: is this considered DSL-independent code?
    # TODO: unique {id}
    # Intermediate shall not contain actual object references, since it might be generated.
    intermediate = Inter.new({
        Inter::TaskRef(:a) => [Inter::Out(:success, :b), Inter::Out(:failure, :c)],
        Inter::TaskRef(:b) => [Inter::Out(:success, :d), Inter::Out(:failure, :c)],
        Inter::TaskRef(:c) => [Inter::Out(:success, "End.failure"), Inter::Out(:failure, "End.failure")],
        Inter::TaskRef(:d) => [Inter::Out(:success, "End.success"), Inter::Out(:failure, "End.success")],
        Inter::TaskRef("End.success", stop_event: true) => [],
        Inter::TaskRef("End.failure", stop_event: true) => [],
      },
      [Inter::TaskRef("End.success"), Inter::TaskRef("End.failure")],
      [Inter::TaskRef(:a)] # start
    )

    implementation = {
      :a => Process::Implementation::Task(implementing.method(:a), [Activity::Output(Right,       :success), Activity::Output(Left, :failure)]),
      :b => Process::Implementation::Task(implementing.method(:b), [Activity::Output("B/success", :success), Activity::Output("B/failure", :failure)]),
      :c => Process::Implementation::Task(implementing.method(:c), [Activity::Output(Right,       :success), Activity::Output(Left, :failure)]),
      :d => Process::Implementation::Task(implementing.method(:d), [Activity::Output("D/success", :success), Activity::Output(Left, :failure)]),
      "End.success" => Process::Implementation::Task(implementing::Success, [Activity::Output(implementing::Success, :success)]), # DISCUSS: End has one Output, signal is itself?
      "End.failure" => Process::Implementation::Task(implementing::Failure, [Activity::Output(implementing::Failure, :failure)]),
    }

    circuit = Inter.circuit(intermediate, implementation)
    pp circuit

    nodes = Inter.node_attributes(implementation)
    # generic NodeAttributes
    pp nodes

    outputs = Inter.outputs(intermediate.stop_task_refs, nodes)
    pp outputs

    process = Trailblazer::Activity::Process.new(circuit, outputs, nodes)

    puts cct = Trailblazer::Developer::Render::Circuit.(process: process)

    cct.must_equal %{
#<Method: #<Module:0x>.a>
 {LinearTest::Right} => #<Method: #<Module:0x>.b>
 {LinearTest::Left} => #<Method: #<Module:0x>.c>
#<Method: #<Module:0x>.b>
 {B/success} => #<Method: #<Module:0x>.d>
 {B/failure} => #<Method: #<Module:0x>.c>
#<Method: #<Module:0x>.c>
 {LinearTest::Right} => #<End/:failure>
 {LinearTest::Left} => #<End/:failure>
#<Method: #<Module:0x>.d>
 {D/success} => #<End/:success>
 {LinearTest::Left} => #<End/:success>
#<End/:success>

#<End/:failure>
}
  end

  # outputs = task.outputs / default

          # default #step
      # :success=>[Right, :success]=>[Search.method(:Forward), :success]
          # override by user
      # :success=>[Right, :success]=>[Search.method(:ById), :blaId]

  # default {step}: Output(outputs[:success].signal, outputs[:success].semantic)=>[Search::Forward, :success], ...
  # compile effective Output(signal, semantic) => Search::<strat>


  # pass_fast: true => outputs+=PassFast, connections+=PassFast
  # id, taskBuilder
  # process_DSL_options Output/Task()

# step
  # normalize (e.g. macro/task)
  # step (original)
  #   PASSFAST::step extending args
  # insert_task...

=begin
Railway.step(my_step_pipeline:Railway.step_pipe)
  my_step_pipeline.(..)
  insert_task

FastTrack.step(my=Railway.step_pipe+..)

=end


  def compile_process(sequence)
    process = Linear::Compiler.(sequence)
  end


  it do
    # {seq} is the succession of steps to compile the options for a {step} call.
    seq = Path.initial_sequence
    seq = Path.step_options_for_path(seq)

    process = compile_process(seq)

    pp process

    signal, (ctx, _) = process.to_h[:circuit].([{}])

    puts "@@@@@ #{ctx.inspect}"

    seq = Railway.step_options(Path.step_options_for_path(Path.initial_sequence))

    process = compile_process(seq)

    pp process

    signal, (ctx, _) = process.to_h[:circuit].([{user_options: {pass_fast: true}}])

    puts "@@@@@RW #{ctx.inspect}"

    # build the Path for FastTrack.step_options
    seq = FastTrack.step_options(Railway.step_options(Path.step_options_for_path(Path.initial_sequence)))

    process = compile_process(seq)

    pp process

    signal, (ctx, _) = process.to_h[:circuit].([{user_options: {pass_fast: true}}])

    puts "@@@@@FTW #{ctx.inspect}"

    signal, (ctx, _) = process.to_h[:circuit].([{user_options: {fast_track: true}}])

    puts "@@@@@FTW2 #{ctx.inspect}"
  end

  it "Path.initial_sequence" do
    seq = Trailblazer::Activity::Path::DSL.initial_sequence

    pp seq
  end

  it "Path.normalizer" do
    seq = Trailblazer::Activity::Path::DSL.normalizer

    process = compile_process(seq)
    circuit = process.to_h[:circuit]

    signal, (ctx, _) = circuit.([{user_options: {}}])

    ctx.inspect.must_equal %{{:connections=>{:success=>[#<Method: Trailblazer::Activity::DSL::Linear::Search.Forward>, :success]}, :outputs=>{:success=>#<struct Trailblazer::Activity::Output signal=Trailblazer::Activity::Right, semantic=:success>}, :user_options=>{}}}
  end

  it "Railway.normalizer" do
    seq = Trailblazer::Activity::Railway::DSL.initial_sequence

    pp seq

    seq = Trailblazer::Activity::Railway::DSL.normalizer

    process = compile_process(seq)
    circuit = process.to_h[:circuit]

    signal, (ctx, _) = circuit.([{user_options: {}}])

    ctx.inspect.must_equal %{{:connections=>{:failure=>[#<Method: Trailblazer::Activity::DSL::Linear::Search.Forward>, :failure], :success=>[#<Method: Trailblazer::Activity::DSL::Linear::Search.Forward>, :success]}, :outputs=>{:failure=>#<struct Trailblazer::Activity::Output signal=Trailblazer::Activity::Right, semantic=:failure>, :success=>#<struct Trailblazer::Activity::Output signal=Trailblazer::Activity::Right, semantic=:success>}, :user_options=>{}}}
  end

  it "Railway.normalizer_for_fail" do
    seq = Trailblazer::Activity::Railway::DSL.initial_sequence

    pp seq

    seq = Trailblazer::Activity::Railway::DSL.normalizer_for_fail

    process = compile_process(seq)
    circuit = process.to_h[:circuit]

    signal, (ctx, _) = circuit.([{user_options: {}}])

    ctx.inspect.must_equal %{{:connections=>{:failure=>[#<Method: Trailblazer::Activity::DSL::Linear::Search.Forward>, :failure], :success=>[#<Method: Trailblazer::Activity::DSL::Linear::Search.Forward>, :failure]}, :outputs=>{:failure=>#<struct Trailblazer::Activity::Output signal=Trailblazer::Activity::Right, semantic=:failure>, :success=>#<struct Trailblazer::Activity::Output signal=Trailblazer::Activity::Right, semantic=:success>}, :user_options=>{}, :magnetic_to=>:failure}}
  end

  describe "FastTrack" do
    let(:normalizer) do
      seq = Trailblazer::Activity::FastTrack::DSL.normalizer

      process = compile_process(seq)
      circuit = process.to_h[:circuit]
    end

    it " accepts :fast_track => true" do
      signal, (ctx, _) = normalizer.([{user_options: {fast_track: true}}])

      ctx.inspect.must_equal %{{:connections=>{:failure=>[#<Method: Trailblazer::Activity::DSL::Linear::Search.Forward>, :failure], :success=>[#<Method: Trailblazer::Activity::DSL::Linear::Search.Forward>, :success], :fail_fast=>[#<Method: Trailblazer::Activity::DSL::Linear::Search.Forward>, :fail_fast], :pass_fast=>[#<Method: Trailblazer::Activity::DSL::Linear::Search.Forward>, :pass_fast]}, :outputs=>{:pass_fast=>#<struct Trailblazer::Activity::Output signal=Trailblazer::Activity::FastTrack::PassFast, semantic=:pass_fast>, :fail_fast=>#<struct Trailblazer::Activity::Output signal=Trailblazer::Activity::FastTrack::FailFast, semantic=:fail_fast>, :failure=>#<struct Trailblazer::Activity::Output signal=Trailblazer::Activity::Right, semantic=:failure>, :success=>#<struct Trailblazer::Activity::Output signal=Trailblazer::Activity::Right, semantic=:success>}, :user_options=>{:fast_track=>true}}}
    end

    it " accepts :pass_fast => true" do
      signal, (ctx, _) = normalizer.([{user_options: {pass_fast: true}}])

      ctx.inspect.must_equal %{{:connections=>{:failure=>[#<Method: Trailblazer::Activity::DSL::Linear::Search.Forward>, :failure], :success=>[#<Method: Trailblazer::Activity::DSL::Linear::Search.Forward>, :pass_fast]}, :outputs=>{:failure=>#<struct Trailblazer::Activity::Output signal=Trailblazer::Activity::Right, semantic=:failure>, :success=>#<struct Trailblazer::Activity::Output signal=Trailblazer::Activity::Right, semantic=:success>}, :user_options=>{:pass_fast=>true}}}
    end

    it " accepts :fail_fast => true" do
      signal, (ctx, _) = normalizer.([{user_options: {fail_fast: true}}])

      ctx.inspect.must_equal %{{:connections=>{:failure=>[#<Method: Trailblazer::Activity::DSL::Linear::Search.Forward>, :fail_fast], :success=>[#<Method: Trailblazer::Activity::DSL::Linear::Search.Forward>, :success]}, :outputs=>{:failure=>#<struct Trailblazer::Activity::Output signal=Trailblazer::Activity::Right, semantic=:failure>, :success=>#<struct Trailblazer::Activity::Output signal=Trailblazer::Activity::Right, semantic=:success>}, :user_options=>{:fail_fast=>true}}}
    end

    it "goes without options" do
      seq = Trailblazer::Activity::FastTrack::DSL.initial_sequence

      pp seq

      seq = Trailblazer::Activity::FastTrack::DSL.normalizer

      process = compile_process(seq)
      circuit = process.to_h[:circuit]

      signal, (ctx, _) = circuit.([{user_options: {}}])

      ctx.inspect.must_equal %{{:connections=>{:failure=>[#<Method: Trailblazer::Activity::DSL::Linear::Search.Forward>, :failure], :success=>[#<Method: Trailblazer::Activity::DSL::Linear::Search.Forward>, :success]}, :outputs=>{:pass_fast=>#<struct Trailblazer::Activity::Output signal=Trailblazer::Activity::FastTrack::PassFast, semantic=:pass_fast>, :fail_fast=>#<struct Trailblazer::Activity::Output signal=Trailblazer::Activity::FastTrack::FailFast, semantic=:fail_fast>, :failure=>#<struct Trailblazer::Activity::Output signal=Trailblazer::Activity::Right, semantic=:failure>, :success=>#<struct Trailblazer::Activity::Output signal=Trailblazer::Activity::Right, semantic=:success>}, :user_options=>{}}}
    end

    describe "normalizer_for_fail" do
      let(:normalizer_for_fail) do
        seq = Trailblazer::Activity::FastTrack::DSL.normalizer_for_fail

        process = compile_process(seq)
        circuit = process.to_h[:circuit]
      end

      it " accepts :fast_track => true" do
        signal, (ctx, _) = normalizer_for_fail.([{user_options: {fast_track: true}}])

        ctx.inspect.must_equal %{{:connections=>{:failure=>[#<Method: Trailblazer::Activity::DSL::Linear::Search.Forward>, :failure], :success=>[#<Method: Trailblazer::Activity::DSL::Linear::Search.Forward>, :failure], :fail_fast=>[#<Method: Trailblazer::Activity::DSL::Linear::Search.Forward>, :fail_fast], :pass_fast=>[#<Method: Trailblazer::Activity::DSL::Linear::Search.Forward>, :pass_fast]}, :outputs=>{:pass_fast=>#<struct Trailblazer::Activity::Output signal=Trailblazer::Activity::FastTrack::PassFast, semantic=:pass_fast>, :fail_fast=>#<struct Trailblazer::Activity::Output signal=Trailblazer::Activity::FastTrack::FailFast, semantic=:fail_fast>, :failure=>#<struct Trailblazer::Activity::Output signal=Trailblazer::Activity::Right, semantic=:failure>, :success=>#<struct Trailblazer::Activity::Output signal=Trailblazer::Activity::Right, semantic=:success>}, :user_options=>{:fast_track=>true}, :magnetic_to=>:failure}}
      end

      it "PROTOTYPING step" do
        signal, (ctx, _) = normalizer.([{user_options: {fast_track: true}}])
        step_options = ctx

        signal, (ctx, _) = normalizer_for_fail.([{user_options: {}}])
        fail_options = ctx

        seq = Trailblazer::Activity::FastTrack::DSL.initial_sequence
        seq = Linear::DSL.insert_task(implementing.method(:a), sequence: seq, id: :a, **step_options)
        seq = Linear::DSL.insert_task(implementing.method(:b), sequence: seq, id: :b, **fail_options)

        process = compile_process(seq)
        circuit = process.to_h[:circuit]
      end
    end
  end


  def default_binary_outputs
    {success: Activity::Output(Activity::Right, :success), failure: Activity::Output(Activity::Left, :failure)}
  end

  def default_step_connections
    {success: [Linear::Search.method(:Forward), :success], failure: [Linear::Search.method(:Forward), :failure]}
  end

  def step(task, sequence:, magnetic_to: :success, outputs: self.default_binary_outputs, connections: self.default_step_connections, sequence_insert: [Linear::Insert.method(:Prepend), "End.success"], **local_options)
    # here, we want the final arguments.
    Linear::DSL.insert_task(task, sequence: sequence, magnetic_to: magnetic_to, outputs: outputs, connections: connections, sequence_insert: sequence_insert, **local_options)
  end

  # fail simply wires both {:failure=>} and {:success=>} outputs to the next {=>:failure} task.
  def fail(task, magnetic_to: :failure, connections: default_step_connections.merge(success: default_step_connections[:failure]), **local_options)
    step(task, magnetic_to: magnetic_to, connections: connections, **local_options)
  end

  # def insert_task_into_sequence!(task, **options, &block)
  #   @sequence = insert_task(task, sequence: @sequence, **options, &block)
  # end

  let(:sequence) do
    start_default = Activity::Start.new(semantic: :default)
    end_success   = Activity::End.new(semantic: :success)
    end_failure   = Activity::End.new(semantic: :failure)

    start_event = Linear::DSL.create_row(start_default, id: "Start.default", magnetic_to: nil, outputs: {success: default_binary_outputs[:success]}, connections: {success: default_step_connections[:success]})
    @sequence   = Linear::Sequence[start_event]

    end_args = {sequence_insert: [Linear::Insert.method(:Append), "Start.default"]}

    @sequence = step(end_failure, sequence: @sequence, magnetic_to: :failure, id: "End.failure", outputs: {failure: end_failure}, connections: {failure: [Linear::Search.method(:Noop)]}, **end_args)
    @sequence = step(end_success, sequence: @sequence, magnetic_to: :success, id: "End.success", outputs: {success: end_success}, connections: {success: [Linear::Search.method(:Noop)]}, **end_args)

  # PassFast
    end_pass_fast   = Activity::End.new(semantic: :pass_fast)
    @sequence = step(end_pass_fast, sequence: @sequence, magnetic_to: :pass_fast, id: "End.pass_fast", outputs: {pass_fast: end_pass_fast}, connections: {pass_fast: [Linear::Search.method(:Noop)]}, sequence_insert: [Linear::Insert.method(:Append), "End.success"])


    @sequence = step implementing.method(:a), sequence: @sequence, id: :a
    @sequence = fail implementing.method(:f), sequence: @sequence, id: :f, connections: {success: [Linear::Search.method(:ById), :d], failure: [Linear::Search.method(:ById), :c]}
    @sequence = step implementing.method(:b), sequence: @sequence, id: :b, outputs: default_binary_outputs.merge(pass_fast: Activity::Output("Special signal", :pass_fast)), connections: default_step_connections.merge(pass_fast: [Linear::Search.method(:Forward), :pass_fast])
    @sequence = fail implementing.method(:c), sequence: @sequence, id: :c
    @sequence = step implementing.method(:d), sequence: @sequence, id: :d
  end

  it "DSL to change {Sequence} and compile it to a {Process}" do
pp sequence
    process = Linear::Compiler.(sequence)

    cct = Trailblazer::Developer::Render::Circuit.(process: process)
    puts cct
    cct.must_equal %{
#<Start/:default>
 {Trailblazer::Activity::Right} => #<Method: #<Module:0x>.a>
#<Method: #<Module:0x>.a>
 {Trailblazer::Activity::Right} => #<Method: #<Module:0x>.b>
 {Trailblazer::Activity::Left} => #<Method: #<Module:0x>.f>
#<Method: #<Module:0x>.f>
 {Trailblazer::Activity::Right} => #<Method: #<Module:0x>.d>
 {Trailblazer::Activity::Left} => #<Method: #<Module:0x>.c>
#<Method: #<Module:0x>.b>
 {Trailblazer::Activity::Right} => #<Method: #<Module:0x>.d>
 {Trailblazer::Activity::Left} => #<Method: #<Module:0x>.c>
 {Special signal} => #<End/:pass_fast>
#<Method: #<Module:0x>.c>
 {Trailblazer::Activity::Right} => #<End/:failure>
 {Trailblazer::Activity::Left} => #<End/:failure>
#<Method: #<Module:0x>.d>
 {Trailblazer::Activity::Right} => #<End/:success>
 {Trailblazer::Activity::Left} => #<End/:failure>
#<End/:success>

#<End/:pass_fast>

#<End/:failure>
}
  end

  it "supports :replace, :delete, :inherit" do
    _sequence = sequence

    _sequence = step implementing.method(:g), sequence: _sequence, id: :g, sequence_insert: [Linear::Insert.method(:Replace), :f]
    _sequence = step nil, sequence: _sequence, id: nil,                    sequence_insert: [Linear::Insert.method(:Delete), :d]
# pp _sequence
    process = Linear::Compiler.(_sequence)

    cct = Trailblazer::Developer::Render::Circuit.(process: process)
    # puts cct
    cct.must_equal %{
#<Start/:default>
 {Trailblazer::Activity::Right} => #<Method: #<Module:0x>.a>
#<Method: #<Module:0x>.a>
 {Trailblazer::Activity::Right} => #<Method: #<Module:0x>.g>
 {Trailblazer::Activity::Left} => #<Method: #<Module:0x>.c>
#<Method: #<Module:0x>.g>
 {Trailblazer::Activity::Right} => #<Method: #<Module:0x>.b>
 {Trailblazer::Activity::Left} => #<Method: #<Module:0x>.c>
#<Method: #<Module:0x>.b>
 {Trailblazer::Activity::Right} => #<End/:success>
 {Trailblazer::Activity::Left} => #<Method: #<Module:0x>.c>
 {Special signal} => #<End/:pass_fast>
#<Method: #<Module:0x>.c>
 {Trailblazer::Activity::Right} => #<End/:failure>
 {Trailblazer::Activity::Left} => #<End/:failure>
#<End/:success>

#<End/:pass_fast>

#<End/:failure>
}
  end

  it "simple linear approach where a {Sequence} is compiled into an Intermediate/Implementation" do
    seq = [
      [
        nil,
        implementing::Start,
        [
          Linear::Search::Forward(
            Activity::Output(Right, :success),
            :success
          ),
        ],
        {id: "Start.default"},
      ],
      [
        :success, # MinusPole
        # [Search::Forward(:success), Search::ById(:a)]
        implementing.method(:a),
        [
          Linear::Search::Forward(
            Activity::Output(Right, :success),
            :success
          ),
          Linear::Search::Forward(
            Activity::Output(Left, :failure),
            :failure
          ),
        ],
        {id: :a},
      ],
      [
        :success,
        implementing.method(:b),
        [
          Linear::Search::Forward(
            Activity::Output("B/success", :success),
            :success
          ),
          Linear::Search::Forward(
            Activity::Output("B/failure", :failure),
            :failure
          )
        ],
        {id: :b},
      ],
      [
        :failure,
        implementing.method(:c),
        [
          Linear::Search::Forward(
            Activity::Output(Right, :success),
            :failure
          ),
          Linear::Search::Forward(
            Activity::Output(Left, :failure),
            :failure
         )
        ],
        {id: :c},
      ],
      [
        :success,
        implementing.method(:d),
        [
          Linear::Search::Forward(
            Activity::Output("D/success", :success),
            :success
          ),
          Linear::Search::Forward(
            Activity::Output(Left, :failure),
            :failure
          )
        ],
        {id: :d},
      ],
      [
        :success,
        implementing::Success,
        [
          Linear::Search::Noop(
            Activity::Output(implementing::Success, :success)
          )
        ],
        {id: "End.success", stop_event: true},
      ],
      [
        :failure,
        implementing::Failure,
        [
          Linear::Search::Noop(
            Activity::Output(implementing::Failure, :failure)
          )
        ],
        {id: "End.failure", stop_event: true},
      ],
    ]

    process = Linear::Compiler.(seq)

    cct = Trailblazer::Developer::Render::Circuit.(process: process)

    cct.must_equal %{
#<Start/:default>
 {LinearTest::Right} => #<Method: #<Module:0x>.a>
#<Method: #<Module:0x>.a>
 {LinearTest::Right} => #<Method: #<Module:0x>.b>
 {LinearTest::Left} => #<Method: #<Module:0x>.c>
#<Method: #<Module:0x>.b>
 {B/success} => #<Method: #<Module:0x>.d>
 {B/failure} => #<Method: #<Module:0x>.c>
#<Method: #<Module:0x>.c>
 {LinearTest::Right} => #<End/:failure>
 {LinearTest::Left} => #<End/:failure>
#<Method: #<Module:0x>.d>
 {D/success} => #<End/:success>
 {LinearTest::Left} => #<End/:failure>
#<End/:success>

#<End/:failure>
}

  end
end

# TODO: test when target can't be found
