defmodule Permutations do
	def make_permutations( input_set, perm_size, condition, result \\ [])
	def make_permutations( _input_set, perm_size, condition, result ) when (length(result) == perm_size) do
		case condition.(result) do
			true -> List.to_tuple(result)
			false -> :failed
		end
	end
	def make_permutations( input_set, perm_size, condition, result ) when (length(input_set)+length(result) >= perm_size) do

		Enum.map( input_set, 
			fn(input_el) ->
				make_permutations( 	input_set--[input_el],
									perm_size,
									condition,
									result++[input_el] )
			end )
				|> List.flatten
					|> Enum.filter(&(&1 != :failed))
	end
end

defmodule ParallelEnum do

	@controller :parallel_enum_control_system

	############
	## public ##
	############

	defmodule IntermediateResult do
		defstruct child_pid: nil, my_own_result: nil
	end

	def parallel_enum_control_system number \\ 1 do
		receive do
			%{ from: sender, query: :get_number} -> 
						send sender, number
						parallel_enum_control_system number
			:increment -> parallel_enum_control_system number+1
			:decrement -> parallel_enum_control_system number-1
			some -> IO.puts "WARNING! Unexpected message in parallel_enum_control_system: #{inspect some}"
		end
	end

	def worker(daddy, func, arg) do
		send @controller, :increment
		send daddy, %{ from: self, result: func.(arg)}
		send @controller, :decrement
	end

	def map lst, func, limit \\ 2 do
		if (:erlang.whereis(@controller) == :undefined ) do
			:erlang.register( @controller,
			spawn(ParallelEnum, :parallel_enum_control_system, [1]) )
		end
		Enum.map(lst, &(try_make_child(&1, func, limit)))
			|> Enum.map( &collect_results/1 )
	end

	#############
	## private ##
	#############

	defp try_make_child(arg, func, limit) do
		case  (get_number_of_processes < limit) do
			false ->
				%IntermediateResult{child_pid: nil,
									my_own_result: func.(arg)} # in this case do work yourself haha 
			true -> 
				%IntermediateResult{child_pid: spawn_link(ParallelEnum, :worker, [self, func, arg]),
									my_own_result: nil} 
		end
	end

	defp get_number_of_processes do
		send @controller, %{ from: self, query: :get_number }
		receive do
			num when is_integer(num) -> num
		end
	end

	defp collect_results( %IntermediateResult{child_pid: nil, my_own_result: result}) do
		result
	end
	defp collect_results( %IntermediateResult{child_pid: pid, my_own_result: nil}) do
		receive do
			%{ from: incoming_pid, result: result} when (incoming_pid == pid) -> result
		end
	end

end

defmodule Horse.Solution do

	
	#########################
	### compile-time work ###
	#########################

	@horse_ways Permutations.make_permutations([-1, -2, 1, 2], 2, fn(lst) -> Enum.reduce(lst, 0, &(abs(&1)+&2)) == 3 end )

	# structs of data
	defmodule Position do
		defstruct	first: 1, second: 1
	end
	defmodule GameState do
		defstruct 	current_pos: %Position{}, path: []
	end

	############################
	### test of performance ####
	############################

	def test_of_performance do
		Enum.each( 1..25, fn(num) -> test_of_performance_process(num) end )
		Enum.each( [50, 75, 100, 150, 200, 250, 500, 1000], 
			fn(num) -> test_of_performance_process(num) end )
	end

	defp test_of_performance_process(num) do
		{res, _} = :timer.tc( fn() -> init(5, num, %Position{}) end )
		File.write "./test_results", "#{num} #{res}\n", [:append]
	end


	####################
	### runtime work ###
	####################

	def init(limit, number_of_processes \\ 2, begin_pos \\ nil ) when (is_integer(limit) and (limit > 0) and (is_integer(number_of_processes)) and (number_of_processes > 0)) do
		:random.seed(:erlang.now)
		[
			%GameState{current_pos: 
				case begin_pos do

					%Position{} -> 	begin_pos
										|> inform_user_about_beginning

					_ -> %Position{	first: :random.uniform(limit),
									second: :random.uniform(limit) }
											|> inform_user_about_beginning  
				end  }
		]
			|> game(limit, number_of_processes)
				|> show_game_results(limit)
	end

	defp inform_user_about_beginning info do
		IO.puts "Hello, user, we begin from #{inspect info}"
		info
	end

	defp game([], _limit, _number_of_processes) do [] end
	defp game(lst, limit, number_of_processes) do
		case game_over?(lst, limit) do
			true -> lst
			false -> ParallelEnum.map(lst,
						&(generate_new_list_and_game_next(&1, limit, number_of_processes)),
						number_of_processes)
							|> List.flatten
		end
	end

	defp game_over?([%GameState{path: path}| _rest], limit) do
		length(path) == (limit*limit - 1)
	end 

	defp generate_new_list_and_game_next(game_state = %GameState{current_pos: current_pos}, limit, number_of_processes) do
		@horse_ways
			|> Enum.map( &(generate_new_position(current_pos, &1)) )
				|> Enum.filter(&( can_go_here?(game_state, &1, limit) ))
					|> Enum.map(&( go_here(game_state, &1) ))
						|> game(limit, number_of_processes)
	end

	defp generate_new_position(	%Position{first: first, second: second},
								{delta1, delta2}  ) do
		%Position{first: (first+delta1), second: (second+delta2)}
	end

	defp can_go_here?(	%GameState{current_pos: current_pos, path: path},
						prompt = %Position{first: first, second: second},
						limit   ) do
		not(prompt in [current_pos | path]) and Enum.all?([first, second], &( (&1 <= limit) and (&1 > 0) ))
	end

	defp go_here( %GameState{current_pos: current_pos, path: path}, prompt ) do
		%GameState{current_pos: prompt, path: path++[current_pos]}
	end

	defp show_game_results([], limit) do
		IO.puts "FAIL. This is no any way to go through desk #{limit}x#{limit} from this position."
	end

	defp show_game_results([%GameState{current_pos: current_pos, path: path} | rest_way], limit) do
		"""
		SUCCESS! There are #{length(rest_way)+1} ways to go through desk #{limit}x#{limit} from this position.
		Here one of them: 
		"""
			|> IO.puts 
		Enum.each( path++[current_pos] , &(IO.puts "\t#{inspect &1}") )
	end

end