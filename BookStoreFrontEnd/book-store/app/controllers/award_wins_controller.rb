class AwardWinsController < ApplicationController
  # GET /award_wins
  def index
    @award_wins = AwardWin.all
  end

  # GET /award_wins/1
  def show
    @award_win = AwardWin.find(params[:id])
  end
end
