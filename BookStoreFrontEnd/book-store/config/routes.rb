BookStore::Application.routes.draw do
  resources :authors, :books, :editions, :publishers, :awards, only: [:index, :show]

  get 'search' => 'searches#new', as: 'search'

  root :to => 'pages#home'
end
