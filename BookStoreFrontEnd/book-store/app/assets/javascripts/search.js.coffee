$('#opt').iphoneStyle
    checkedLabel: 'More results'
    uncheckedLabel: 'Better results'

$('#search').submit ->
    $('#content').fadeOut 'normal', ->
        $('#loader').fadeIn 'normal'
