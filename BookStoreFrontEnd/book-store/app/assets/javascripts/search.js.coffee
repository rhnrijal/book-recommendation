$('#opt').iphoneStyle
    checkedLabel: 'More results'
    uncheckedLabel: 'Better results'

$('#search').submit ->
    if $('#results').length
        $('#results').fadeOut 'normal', ->
            $('#loader').fadeIn 'normal'
    else
        $('#loader').fadeIn 'normal'
