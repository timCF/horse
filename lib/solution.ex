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

	@pgname "ParallelEnum_process_group"

	def map lst, func, limit \\ 2
	def map lst, func, limit do
		IO.puts "main proc #{inspect self}"
		Enum.reduce(lst, [], fn(el, res) -> res++[try_make_child(el, func, limit)] end)
			|> Enum.map( &collect_results/1 )
	end

	defmodule IntermediateResult do
		defstruct child_pid: nil, my_own_result: nil
	end

	defp worker(daddy, func, arg) do
		IO.inspect send daddy, %{ from: self, result: func.(arg)}
	end

	defp try_make_child(arg, func, limit) do
		case can_make_child?(limit) do
			false ->
				%IntermediateResult{child_pid: nil,
									my_own_result: func.(arg)} # in this case do work yourself haha 
			true -> 
				%IntermediateResult{child_pid: spawn_link(fn() -> worker(self, func, arg) end),
									my_own_result: nil} 
		end
	end

	defp can_make_child?(limit) do
		:pg2.create @pgname
		length(:pg2.get_members @pgname) < limit
	end

	defp collect_results( %IntermediateResult{child_pid: nil, my_own_result: result}) do
		result
	end
	defp collect_results( %IntermediateResult{child_pid: pid, my_own_result: nil}) do
		IO.puts "collecter proc #{inspect self}"
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

	####################
	### runtime work ###
	####################

	def init(limit) when (is_integer(limit) and (limit > 0)) do
		:random.seed(:erlang.now)
		[
			%GameState{current_pos: %Position{	first: :random.uniform(limit),
												second: :random.uniform(limit)}
													|> inform_user_about_beginning   }
		]
			|> game(limit)
				|> show_game_results(limit)
	end

	defp inform_user_about_beginning info do
		IO.puts "Hello, user, we begin from #{inspect info}"
		info
	end

	defp game([], _limit) do [] end
	defp game(lst, limit) do
		case game_over?(lst, limit) do
			true -> lst
			false -> Enum.map(lst,
						&(generate_new_list_and_game_next(&1, limit)))
							|> List.flatten
		end
	end

	defp game_over?([%GameState{path: path}| _rest], limit) do
		length(path) == (limit*limit - 1)
	end 

	defp generate_new_list_and_game_next(game_state = %GameState{current_pos: current_pos}, limit) do
		@horse_ways
			|> Enum.map( &(generate_new_position(current_pos, &1)) )
				|> Enum.filter(&( can_go_here?(game_state, &1, limit) ))
					|> Enum.map(&( go_here(game_state, &1) ))
						|> game(limit)
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